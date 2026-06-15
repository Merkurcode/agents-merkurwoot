class Email::ResendEventService
  HANDLED_EVENTS = %w[email.bounced email.complained email.delivered email.opened email.clicked].freeze

  def initialize(webhook_payload)
    @webhook_payload = webhook_payload
  end

  def perform
    return unless HANDLED_EVENTS.include?(@webhook_payload['type'])

    case @webhook_payload['type']
    when 'email.bounced'    then handle_bounce
    when 'email.complained' then handle_complaint
    when 'email.delivered' then handle_delivered
    when 'email.opened'    then handle_opened
    when 'email.clicked'   then handle_clicked
    end
  end

  private

  def event_type
    @webhook_payload['type']
  end

  def to_addresses
    Array(@webhook_payload.dig('data', 'to'))
  end

  def from_address
    @webhook_payload.dig('data', 'from')
  end

  def bounce_data
    @webhook_payload.dig('data', 'bounce') || {}
  end

  def hard_bounce?
    bounce_data['type'].to_s.downcase == 'hard'
  end

  def handle_bounce
    contacts_for_recipients.each do |contact|
      reason = bounce_data['message'].presence || bounce_data['type'].presence || 'unknown'
      create_private_note(contact, "⚠️ Bounce (#{bounce_data['type'] || 'unknown'}): #{reason}")

      next unless hard_bounce?

      contact.update!(
        custom_attributes: contact.custom_attributes.merge(
          'email_bounced' => true,
          'email_bounced_at' => Time.current.iso8601,
          'email_bounce_reason' => reason
        )
      )
    end
  end

  def handle_complaint
    contacts_for_recipients.each do |contact|
      contact.update!(
        custom_attributes: contact.custom_attributes.merge(
          'email_opted_out' => true,
          'email_opted_out_at' => Time.current.iso8601,
          'email_opt_out_reason' => 'spam_complaint'
        )
      )
      create_private_note(contact, '🚫 Spam complaint — contacto marcado como opt-out automáticamente')
    end
  end

  def handle_delivered
    log_event('delivered')
  end

  def handle_opened
    log_event('opened')
  end

  def handle_clicked
    log_event('clicked')
  end

  def log_event(label)
    Rails.logger.info(
      "Resend event #{label} for email_id=#{@webhook_payload.dig('data', 'email_id')} to=#{to_addresses.join(',')}"
    )
  end

  def contacts_for_recipients
    Contact.where(email: to_addresses.map { |e| e.to_s.downcase })
  end

  def create_private_note(contact, content)
    conversation = contact.conversations.order(created_at: :desc).first
    return unless conversation

    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :outgoing,
      private: true,
      content: content
    )
  end
end
