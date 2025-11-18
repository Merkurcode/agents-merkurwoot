# frozen_string_literal: true

class Whatsapp::Providers::WhapiCloudService < Whatsapp::Providers::BaseService
  def send_message(phone_number, message)
    @message = message

    if message.attachments.present?
      send_attachment_message(phone_number, message)
    elsif message.content_type == 'input_select'
      send_interactive_text_message(phone_number, message)
    else
      send_text_message(phone_number, message)
    end
  end

  def send_template(_phone_number, _template_info, _message)
    raise NotImplementedError, 'WhatsApp Light does not support template messages'
  end

  def sync_templates
    # WhatsApp Light does not support templates
    true
  end

  def validate_provider_config?
    return false if whatsapp_channel.provider_config['channel_id'].blank?
    return false if whatsapp_channel.provider_config['token'].blank?

    # Validate with Whapi health endpoint
    response = HTTParty.get(
      "#{api_base_url}/health",
      headers: api_headers
    )

    response.success?
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP LIGHT] Validation failed: #{e.message}"
    false
  end

  def api_headers
    {
      'Authorization' => "Bearer #{whatsapp_channel.provider_config['token']}",
      'Accept' => 'application/json',
      'Content-Type' => 'application/json'
    }
  end

  def media_url(media_id)
    "#{api_base_url}/media/#{media_id}"
  end

  def api_base_url
    url = whatsapp_channel.provider_config['api_url'] || ENV.fetch('WHAPI_GATE_URL', 'https://gate.whapi.cloud')
    url.chomp('/')
  end

  def error_message(response)
    response.parsed_response&.dig('message') || response.parsed_response&.dig('error')
  end

  private

  def send_text_message(phone_number, message)
    response = HTTParty.post(
      "#{api_base_url}/messages/text",
      headers: api_headers,
      body: {
        to: format_phone_number(phone_number),
        body: message.outgoing_content
      }.to_json
    )

    process_response(response, message)
  end

  def send_attachment_message(phone_number, message)
    attachment = message.attachments.first
    type = map_attachment_type(attachment.file_type)

    body = {
      to: format_phone_number(phone_number),
      media: attachment.download_url
    }

    body[:caption] = message.outgoing_content if message.outgoing_content.present? && type != 'audio'

    response = HTTParty.post(
      "#{api_base_url}/messages/#{type}",
      headers: api_headers,
      body: body.to_json
    )

    process_response(response, message)
  end

  def send_interactive_text_message(phone_number, message)
    payload = create_payload_based_on_items(message)

    response = HTTParty.post(
      "#{api_base_url}/messages/interactive",
      headers: api_headers,
      body: {
        to: format_phone_number(phone_number),
        interactive: payload
      }.to_json
    )

    process_response(response, message)
  end

  def format_phone_number(phone_number)
    # Whapi expects phone numbers without + prefix
    phone_number.gsub(/^\+/, '') + '@s.whatsapp.net'
  end

  def map_attachment_type(file_type)
    case file_type
    when 'image' then 'image'
    when 'audio' then 'audio'
    when 'video' then 'video'
    else 'document'
    end
  end

  def process_response(response, message)
    parsed_response = response.parsed_response

    if response.success? && parsed_response['id'].present?
      parsed_response['id']
    else
      handle_error(response, message)
      nil
    end
  end
end
