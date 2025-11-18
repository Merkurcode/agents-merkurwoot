# frozen_string_literal: true

class Whatsapp::IncomingMessageWhapiService
  pattr_initialize [:inbox!, :params!]

  def perform
    return if message_already_processed?
    return if params['from_me'] # Skip messages sent by us

    set_contact
    return unless @contact

    ActiveRecord::Base.transaction do
      set_conversation
      create_message
    end
  end

  private

  def message_already_processed?
    inbox.messages.exists?(source_id: params['id'])
  end

  def set_contact
    phone_number = extract_phone_number(params['chat_id'] || params['from'])
    contact_name = params.dig('from_name') || params.dig('chat', 'name') || phone_number

    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: phone_number,
      inbox: inbox,
      contact_attributes: {
        name: contact_name,
        phone_number: "+#{phone_number}"
      }
    ).perform

    @contact_inbox = contact_inbox
    @contact = contact_inbox.contact
  end

  def set_conversation
    @conversation = ::Conversation.find_by(conversation_params) || build_conversation
    @conversation.save!
  end

  def build_conversation
    ::Conversation.new(conversation_params.merge(
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id
    ))
  end

  def conversation_params
    {
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id
    }
  end

  def create_message
    @message = @conversation.messages.create!(message_params)
    attach_files if attachment_present?
    attach_location if location_present?
    @message
  end

  def message_params
    {
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      message_type: :incoming,
      content: message_content,
      source_id: params['id'],
      sender: @contact,
      external_created_at: params['timestamp'] ? Time.zone.at(params['timestamp']) : Time.current
    }
  end

  def message_content
    case message_type
    when 'text'
      params.dig('text', 'body') || params['body']
    when 'image', 'video', 'audio', 'document', 'voice'
      params.dig(message_type, 'caption') || ''
    when 'location'
      "Location: #{params.dig('location', 'name') || 'Shared location'}"
    when 'contact', 'contacts'
      "Contact: #{params.dig('contacts', 0, 'name', 'formatted_name') || 'Shared contact'}"
    else
      ''
    end
  end

  def message_type
    params['type'] || 'text'
  end

  def attachment_present?
    %w[image video audio document voice sticker].include?(message_type)
  end

  def location_present?
    message_type == 'location'
  end

  def attach_files
    media_data = params[message_type]
    return unless media_data

    media_url = media_data['link'] || media_data['url']
    return unless media_url

    attachment_params = {
      remote_file_url: media_url,
      file_type: file_type_from_message_type,
      account_id: @conversation.account_id
    }

    attachment = @message.attachments.new(attachment_params)
    attachment.file.attach(io: Down.download(media_url), filename: filename_from_media_data(media_data))
    attachment.save!
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP LIGHT] Attachment processing error: #{e.message}"
  end

  def attach_location
    location = params['location']
    return unless location

    @message.content_attributes = {
      latitude: location['latitude'],
      longitude: location['longitude'],
      name: location['name'],
      address: location['address']
    }
    @message.save!
  end

  def file_type_from_message_type
    case message_type
    when 'image' then :image
    when 'video' then :video
    when 'audio', 'voice' then :audio
    when 'document', 'sticker' then :file
    else :file
    end
  end

  def filename_from_media_data(media_data)
    media_data['filename'] || media_data['caption'] || "#{message_type}-#{Time.current.to_i}"
  end

  def extract_phone_number(chat_id)
    # Whapi format: "1234567890@s.whatsapp.net" or "1234567890-1234567890@g.us" (group)
    chat_id.to_s.split('@').first.split('-').first
  end
end
