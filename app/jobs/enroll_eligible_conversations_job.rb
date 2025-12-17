class EnrollEligibleConversationsJob < ApplicationJob
  queue_as :default

  # Process in batches to avoid memory issues with millions of conversations
  BATCH_SIZE = 500

  def perform(sequence_id)
    sequence = LeadFollowUpSequence.find_by(id: sequence_id)
    return unless sequence&.active?

    first_step = sequence.enabled_steps.first
    unless first_step
      Rails.logger.warn "Sequence #{sequence.id} has no enabled steps, skipping enrollment"
      return
    end

    Rails.logger.info "Auto-enrolling conversations for sequence #{sequence.id} (#{sequence.name})"

    enrolled_count = 0
    skipped_count = 0
    start_time = Time.current

    conversations = build_eligible_conversations_query(sequence)

    conversations.in_batches(of: BATCH_SIZE) do |batch|
      if sequence.settings.dig('stop_on_contact_reply')
        batch = filter_by_last_message(batch)
      end

      batch.each do |conversation|
        enroll_conversation(conversation, sequence, first_step)
        enrolled_count += 1
      rescue StandardError => e
        Rails.logger.error "Failed to enroll conversation #{conversation.id}: #{e.message}"
        skipped_count += 1
      end

      Rails.logger.debug "Processed batch: #{enrolled_count} enrolled, #{skipped_count} skipped"
    end

    duration = Time.current - start_time
    Rails.logger.info "Auto-enrollment complete for sequence #{sequence.id} in #{duration.round(2)}s: " \
                      "Enrolled: #{enrolled_count}, Skipped: #{skipped_count}"
  end

  private

  ALLOWED_DATE_COLUMNS = {
    'conversation_created_at' => 'conversations.created_at',
    'inactive_days' => 'conversations.last_activity_at'
  }.freeze

  def build_eligible_conversations_query(sequence)
    query = Conversation
            .where(account_id: sequence.account_id, inbox_id: sequence.inbox_id)

    query = query
            .left_joins(:conversation_follow_up)
            .where(conversation_follow_up: { id: nil })

    query = apply_date_filter(query, sequence)

    query = apply_status_filter(query, sequence)

    query = apply_pipeline_status_filter(query, sequence)

    query = apply_label_filter(query, sequence)

    query
  end

  def apply_status_filter(query, sequence)
    filter = sequence.trigger_conditions&.dig('status_filter')

    if filter&.dig('enabled') && filter['statuses'].present?
      query.where(status: filter['statuses'])
    else
      query.where(status: %i[open pending])
    end
  end

  def apply_pipeline_status_filter(query, sequence)
    filter = sequence.trigger_conditions&.dig('pipeline_status_filter')

    if filter&.dig('enabled') && filter['pipeline_status_ids'].present?
      query.where(pipeline_status_id: filter['pipeline_status_ids'])
    else
      query
    end
  end

  def apply_date_filter(query, sequence)
    filter = sequence.trigger_conditions&.dig('date_filter')

    if filter&.dig('enabled')
      filter_type = filter['filter_type']

      if filter_type == 'last_message_at'
        apply_last_message_date_filter(query, filter)
      elsif ALLOWED_DATE_COLUMNS.key?(filter_type)
        column = ALLOWED_DATE_COLUMNS[filter_type]
        apply_date_operator(query, column, filter)
      else
        Rails.logger.warn "Unknown date filter type: #{filter_type}"
        query
      end
    else
      query.where('conversations.created_at > ?', 30.days.ago)
    end
  end

  def apply_date_operator(query, column, filter)
    case filter['operator']
    when 'older_than'
      query.where("#{column} < ?", filter['value'].to_i.days.ago)
    when 'newer_than'
      query.where("#{column} > ?", filter['value'].to_i.days.ago)
    when 'between'
      from_date = Date.parse(filter['from_date']).beginning_of_day
      to_date = Date.parse(filter['to_date']).end_of_day
      query.where("#{column} BETWEEN ? AND ?", from_date, to_date)
    else
      query
    end
  rescue ArgumentError => e
    Rails.logger.error "Invalid date in filter: #{e.message}"
    query
  end

  def apply_last_message_date_filter(query, filter)
    case filter['operator']
    when 'older_than'
      cutoff_date = filter['value'].to_i.days.ago
      query.where(
        'conversations.id IN (
          SELECT conversation_id
          FROM messages
          WHERE messages.conversation_id = conversations.id
          GROUP BY conversation_id
          HAVING MAX(messages.created_at) < ?
        )',
        cutoff_date
      )
    when 'newer_than'
      cutoff_date = filter['value'].to_i.days.ago
      query.where(
        'conversations.id IN (
          SELECT conversation_id
          FROM messages
          WHERE messages.conversation_id = conversations.id
          GROUP BY conversation_id
          HAVING MAX(messages.created_at) > ?
        )',
        cutoff_date
      )
    when 'between'
      from_date = Date.parse(filter['from_date']).beginning_of_day
      to_date = Date.parse(filter['to_date']).end_of_day
      query.where(
        'conversations.id IN (
          SELECT conversation_id
          FROM messages
          WHERE messages.conversation_id = conversations.id
          GROUP BY conversation_id
          HAVING MAX(messages.created_at) BETWEEN ? AND ?
        )',
        from_date,
        to_date
      )
    else
      query
    end
  rescue ArgumentError => e
    Rails.logger.error "Invalid date in last_message_at filter: #{e.message}"
    query
  end

  def apply_label_filter(query, sequence)
    filter = sequence.trigger_conditions&.dig('label_filter')

    if filter&.dig('enabled') && filter['labels'].present?
      query.where(
        "string_to_array(conversations.cached_label_list, ', ') && ARRAY[?]::varchar[]",
        filter['labels']
      )
    else
      query
    end
  end

  def filter_by_last_message(batch)
    conversation_ids = batch.pluck(:id)
    return batch if conversation_ids.empty?

    valid_conversation_ids = Conversation
                             .where(id: conversation_ids)
                             .where(
                               'conversations.id NOT IN (
                                 SELECT DISTINCT m1.conversation_id
                                 FROM messages m1
                                 WHERE m1.conversation_id IN (?)
                                   AND m1.message_type = 0
                                   AND m1.created_at = (
                                     SELECT MAX(m2.created_at)
                                     FROM messages m2
                                     WHERE m2.conversation_id = m1.conversation_id
                                   )
                               )',
                               conversation_ids
                             )
                             .pluck(:id)

    batch.where(id: valid_conversation_ids)
  end

  def enroll_conversation(conversation, sequence, first_step)
    next_action_at = if first_step['type'] == 'wait'
                       calculate_wait_time(first_step)
                     else
                       Time.current
                     end

    follow_up = ConversationFollowUp.create!(
      conversation: conversation,
      lead_follow_up_sequence: sequence,
      current_step: 0,
      next_action_at: next_action_at,
      status: 'active',
      metadata: {
        enrolled_at: Time.current,
        enrolled_via: 'auto_enroll_on_sequence_activation'
      }
    )

    follow_up.schedule_job!
  end

  def calculate_wait_time(step)
    return Time.current unless step['type'] == 'wait'

    config = step['config']
    delay = config['delay_value'].to_i

    case config['delay_type']
    when 'minutes'
      Time.current + delay.minutes
    when 'hours'
      Time.current + delay.hours
    when 'days'
      Time.current + delay.days
    else
      Time.current + delay.hours
    end
  end
end
