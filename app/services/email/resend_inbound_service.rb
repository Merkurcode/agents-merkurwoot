class Email::ResendInboundService
  class ConversationNotFound < StandardError; end

  RESEND_API_BASE = 'https://api.resend.com'.freeze
  RESEND_RECEIVED_PATHS = ['/emails/received/%<id>s', '/emails/%<id>s'].freeze
  PLUS_ADDRESS_REGEX = /reply\+([a-zA-Z0-9-]+)@/

  def initialize(webhook_payload)
    @webhook_payload = webhook_payload
  end

  def perform
    return unless email_received?

    email_details = fetch_email_from_resend || {}
    conversation = find_conversation(email_details)
    raise ConversationNotFound, "no conversation matched (email_id=#{email_id})" unless conversation

    create_incoming_message(conversation, email_details)
  end

  private

  def email_received?
    @webhook_payload['type'] == 'email.received'
  end

  def email_id
    @webhook_payload.dig('data', 'email_id')
  end

  def webhook_to_addresses
    Array(@webhook_payload.dig('data', 'to'))
  end

  def fetch_email_from_resend
    RESEND_RECEIVED_PATHS.each do |path_template|
      path = format(path_template, id: email_id)
      response = HTTParty.get(
        "#{RESEND_API_BASE}#{path}",
        headers: {
          'Authorization' => "Bearer #{ENV.fetch('RESEND_API_KEY')}",
          'Content-Type' => 'application/json'
        },
        timeout: 15
      )
      return response.parsed_response if response.success?

      Rails.logger.warn("Resend received-email fetch failed (#{path}): #{response.code}")
    end
    nil
  end

  def find_conversation(email)
    find_by_plus_addressing || find_by_in_reply_to(email)
  end

  def find_by_plus_addressing
    webhook_to_addresses.each do |addr|
      match = addr.to_s.match(PLUS_ADDRESS_REGEX)
      next unless match

      convo = Conversation.find_by(uuid: match[1])
      return convo if convo
    end
    nil
  end

  def find_by_in_reply_to(email)
    in_reply_to = extract_in_reply_to(email)
    return nil if in_reply_to.blank?

    normalized = in_reply_to.to_s.gsub(/[<>]/, '').strip
    Message.find_by(source_id: normalized)&.conversation
  end

  def extract_in_reply_to(email)
    headers = email['headers'] || {}
    headers['in-reply-to'] || headers['In-Reply-To']
  end

  def extract_message_id(email)
    headers = email['headers'] || {}
    raw = headers['message-id'] || headers['Message-ID'] || email['message_id'] || @webhook_payload.dig('data', 'message_id')
    raw.to_s.gsub(/[<>]/, '').strip.presence
  end

  def create_incoming_message(conversation, email)
    message_id = extract_message_id(email)
    return if message_id.present? && conversation.messages.find_by(source_id: message_id).present?

    text_body = email['text'].presence
    html_body = email['html'].presence
    subject = email['subject'] || @webhook_payload.dig('data', 'subject')
    content = text_body.presence || sanitize_html(html_body).presence || subject.presence || '(empty reply)'

    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      sender: conversation.contact,
      message_type: 'incoming',
      content_type: 'incoming_email',
      content: content,
      source_id: message_id,
      content_attributes: {
        email: {
          from: Array(email['from'] || @webhook_payload.dig('data', 'from')).compact,
          to: Array(email['to'] || webhook_to_addresses).compact,
          subject: subject,
          message_id: message_id,
          in_reply_to: extract_in_reply_to(email),
          text_content: { reply: text_body, full: text_body },
          html_content: { reply: html_body, full: html_body }
        }.compact
      }
    )
  end

  def sanitize_html(html)
    return '' if html.blank?

    ActionView::Base.full_sanitizer.sanitize(html).to_s.presence || ''
  end
end
