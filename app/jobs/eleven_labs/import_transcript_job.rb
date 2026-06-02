module ElevenLabs
  class ImportTranscriptJob < ApplicationJob
    queue_as :default

    def perform(conversation_id, transcript, start_time_unix_secs = nil)
      conversation = Conversation.find_by(id: conversation_id)
      return unless conversation
      return if transcript.blank?
      return if conversation.additional_attributes['transcript_imported']

      contact = conversation.contact
      call_start = start_time_unix_secs ? Time.at(start_time_unix_secs.to_i) : conversation.created_at

      last_timestamp = call_start

      ActiveRecord::Base.transaction do
        transcript.each do |turn|
          timestamp = call_start + turn['time_in_call_secs'].to_i.seconds
          last_timestamp = timestamp

          create_message(conversation, turn, contact, timestamp) if turn['message'].present?
          create_tool_call_activities(conversation, turn, timestamp)
        end

        conversation.update!(
          agent_last_seen_at: last_timestamp,
          contact_last_seen_at: last_timestamp,
          additional_attributes: conversation.additional_attributes.merge('transcript_imported' => true)
        )
      end
    end

    private

    def create_message(conversation, turn, contact, timestamp)
      additional = {
        'time_in_call_secs' => turn['time_in_call_secs'],
        'source_medium' => turn['source_medium'],
        'interrupted' => turn['interrupted']
      }

      if turn['role'] == 'agent'
        if turn['agent_metadata'].present?
          meta = turn['agent_metadata']
          additional['agent_id'] = meta['agent_id']
          additional['branch_id'] = meta['branch_id']
          additional['version_id'] = meta['version_id']
        end

        llm_cost = extract_llm_cost(turn['llm_usage'])
        additional['llm_cost'] = llm_cost if llm_cost
      end

      conversation.messages.create!(
        account_id: conversation.account_id,
        inbox_id: conversation.inbox_id,
        message_type: turn['role'] == 'user' ? :incoming : :outgoing,
        content_type: :text,
        status: :read,
        content: turn['message'],
        sender: turn['role'] == 'user' ? contact : nil,
        additional_attributes: additional.compact_blank,
        created_at: timestamp
      )
    end

    def parse_json_safely(value)
      return nil if value.blank?
      return value if value.is_a?(Hash) || value.is_a?(Array)

      JSON.parse(value)
    rescue JSON::ParserError
      value
    end

    def extract_llm_cost(llm_usage)
      return nil if llm_usage.blank?

      model_usage = llm_usage['model_usage'] || {}
      total = model_usage.values.sum do |usage|
        (usage.dig('input', 'price') || 0) + (usage.dig('output_total', 'price') || 0)
      end

      total.positive? ? total.round(8) : nil
    end

    def create_tool_call_activities(conversation, turn, timestamp)
      Array(turn['tool_calls']).each do |tool_call|
        next if tool_call['tool_name'].blank?

        details = tool_call['tool_details'] || {}
        additional = {
          'time_in_call_secs' => turn['time_in_call_secs'],
          'tool_name' => tool_call['tool_name'],
          'tool_type' => tool_call['type'],
          'request_id' => tool_call['request_id'],
          'url' => details['url'],
          'method' => details['method'],
          'path_params' => details['path_params'],
          'query_params' => details['query_params'].presence,
          'body' => details['body'],
          'params' => parse_json_safely(tool_call['params_as_json'])
        }.compact_blank

        conversation.messages.create!(
          account_id: conversation.account_id,
          inbox_id: conversation.inbox_id,
          message_type: :activity,
          content_type: :text,
          status: :read,
          content: "Tool invoked: #{tool_call['tool_name']}",
          additional_attributes: additional,
          created_at: timestamp
        )
      end

      Array(turn['tool_results']).each do |tool_result|
        next if tool_result['tool_name'].blank?

        parsed_result = parse_json_safely(tool_result['result_value'])

        content = if tool_result['is_error']
                    "Tool #{tool_result['tool_name']} failed"
                  else
                    "Tool #{tool_result['tool_name']} completed"
                  end

        additional = {
          'time_in_call_secs' => turn['time_in_call_secs'],
          'tool_name' => tool_result['tool_name'],
          'is_error' => tool_result['is_error'],
          'error_type' => tool_result['error_type'],
          'response' => parsed_result,
          'raw_error' => parse_json_safely(tool_result['raw_error_message']),
          'tool_latency_secs' => tool_result['tool_latency_secs'],
          'dynamic_variable_updates' => tool_result['dynamic_variable_updates'].presence,
          'is_blocked' => tool_result['is_blocked']
        }.compact_blank

        conversation.messages.create!(
          account_id: conversation.account_id,
          inbox_id: conversation.inbox_id,
          message_type: :activity,
          content_type: :text,
          status: :read,
          content: content,
          additional_attributes: additional,
          created_at: timestamp
        )
      end
    end
  end
end
