# frozen_string_literal: true

class Webhooks::WhapiEventsJob < ApplicationJob
  queue_as :default

  def perform(inbox_id, payload_json)
    @inbox = Inbox.find_by(id: inbox_id)
    return unless @inbox
    return unless @inbox.channel.is_a?(Channel::Whatsapp)
    return unless @inbox.channel.provider == 'whatsapp_light'

    @payload = JSON.parse(payload_json)

    process_event
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP LIGHT] Event processing error for inbox #{inbox_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  private

  def process_event
    event_type = @payload['event']

    case event_type
    when 'messages'
      process_message_event
    when 'statuses'
      process_status_event
    when 'chats'
      process_chat_event
    else
      Rails.logger.info "[WHATSAPP LIGHT] Unhandled event type: #{event_type}"
    end
  end

  def process_message_event
    messages = @payload['messages'] || [@payload['message']]
    messages.each do |message_data|
      next if message_data['from_me'] # Skip messages sent by us

      Whatsapp::IncomingMessageWhapiService.new(
        inbox: @inbox,
        params: message_data
      ).perform
    end
  end

  def process_status_event
    # Handle message status updates (sent, delivered, read, etc.)
    status_data = @payload['status'] || @payload
    message_id = status_data['id']
    status = status_data['status']

    message = @inbox.messages.find_by(source_id: message_id)
    return unless message

    case status
    when 'sent'
      message.update(status: :sent)
    when 'delivered'
      message.update(status: :delivered)
    when 'read'
      message.update(status: :read)
    when 'failed'
      message.update(status: :failed)
    end

    Rails.logger.info "[WHATSAPP LIGHT] Message #{message_id} status updated to #{status}"
  end

  def process_chat_event
    # Handle chat events (new chat, chat archived, etc.)
    Rails.logger.info "[WHATSAPP LIGHT] Chat event received: #{@payload.inspect}"
  end
end
