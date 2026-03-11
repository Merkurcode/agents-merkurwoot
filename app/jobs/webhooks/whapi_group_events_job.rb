# frozen_string_literal: true

class Webhooks::WhapiGroupEventsJob < ApplicationJob
  queue_as :default

  def perform(event_type, payload_json)
    @event_type = event_type
    @payload = JSON.parse(payload_json)

    process_event
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP GROUPS] Event processing error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  private

  def process_event
    case @event_type
    when 'messages'
      process_message_event
    when 'statuses'
      process_status_event
    when 'groups'
      process_group_event
    else
      Rails.logger.info "[WHATSAPP GROUPS] Unhandled event type: #{@event_type}"
    end
  end

  def process_status_event
    # Handle message status updates for group messages
    statuses = @payload['statuses'] || [@payload['status']].compact

    statuses.each do |status_data|
      next unless status_data

      message_id = status_data['id']
      status = status_data['status']

      Rails.logger.info "[WHATSAPP GROUPS] Processing status update for message #{message_id}: #{status}"

      # Find message across all inboxes since this is a global webhook
      message = Message.find_by(source_id: message_id)
      unless message
        Rails.logger.warn "[WHATSAPP GROUPS] Message not found for source_id: #{message_id}"
        next
      end

      # Map Whapi status to Chatwoot status
      new_status = map_whapi_status(status)

      if new_status
        message.update(status: new_status)
        Rails.logger.info "[WHATSAPP GROUPS] Message #{message_id} status updated to #{new_status}"
      end
    end
  end

  def map_whapi_status(status)
    case status
    when 'sent', 'pending'
      :sent
    when 'delivered'
      :delivered
    when 'read'
      :read
    when 'failed', 'error'
      :failed
    else
      Rails.logger.info "[WHATSAPP GROUPS] Unknown status: #{status}"
      nil
    end
  end

  def process_message_event
    messages = @payload['messages'] || [@payload['message']]
    messages.each do |message_data|
      next unless message_data['chat_id']&.include?('@g.us')

      message_type = message_data['from_me'] ? 'outgoing' : 'incoming'
      Rails.logger.info "[WHATSAPP GROUPS] Processing #{message_type} group message: #{message_data['id']}"
      process_group_message(message_data)
    end
  end

  def process_group_message(message_data)
    group_id = message_data['chat_id']

    conversation = Conversation.whatsapp_group.find_by(whatsapp_group_id: group_id)
    unless conversation
      Rails.logger.warn "[WHATSAPP GROUPS] No conversation found for group: #{group_id}"
      return
    end

    Rails.logger.info "[WHATSAPP GROUPS] Processing message for conversation #{conversation.id}"

    inbox = conversation.inbox
    sender = find_or_create_sender(message_data, conversation.account, inbox)
    contact = sender.is_a?(User) ? conversation.contact : sender

    Whatsapp::IncomingMessageWhapiService.new(
      inbox: inbox,
      params: message_data,
      contact: contact
    ).perform
  end

  def find_or_create_sender(message_data, account, inbox)
    phone = "+#{message_data['from']}"
    name = message_data['from_name'].presence || phone

    user = account.users.find { |u| u.phone_number == phone }
    return user if user

    contact = account.contacts.find_by(phone_number: phone)
    unless contact
      contact = account.contacts.create!(name: name, phone_number: phone)
      ContactInbox.find_or_create_by!(contact: contact, inbox: inbox) do |ci|
        ci.source_id = message_data['from']
      end
    end

    contact
  end

  def process_group_event
    groups_participants = @payload['groups_participants'] || []

    groups_participants.each do |participant_event|
      case participant_event['action']
      when 'add'
        handle_participants_added(participant_event)
      else
        Rails.logger.info "[WHATSAPP GROUPS] Unhandled group action: #{participant_event['action']}"
      end
    end
  end

  def handle_participants_added(participant_event)
    group_id = participant_event['group_id']
    conversation = Conversation.whatsapp_group.find_by(whatsapp_group_id: group_id)

    unless conversation
      Rails.logger.warn "[WHATSAPP GROUPS] No conversation found for group: #{group_id}"
      return
    end

    participant_event['participants'].each do |phone|
      add_participant_to_conversation(phone, conversation)
    end
  end

  def add_participant_to_conversation(phone, conversation)
    formatted_phone = "+#{phone}"
    contact = conversation.account.contacts.find_by(phone_number: formatted_phone)
    contact ||= conversation.account.contacts.create!(name: formatted_phone, phone_number: formatted_phone)

    participants = conversation.additional_attributes['participants'] || []
    return if participants.any? { |p| p['whapi_id'] == phone }

    participants << { 'rank' => 'member', 'phone' => phone, 'whapi_id' => phone, 'user_id' => nil, 'contact_id' => contact.id }

    conversation.update!(additional_attributes: conversation.additional_attributes.merge('participants' => participants))
    Rails.logger.info "[WHATSAPP GROUPS] Added participant #{phone} (contact #{contact.id}) to conversation #{conversation.id}"
  end
end
