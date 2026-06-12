module ResendComplianceHeaders
  extend ActiveSupport::Concern

  UNSUBSCRIBE_VERIFIER_PURPOSE = :resend_unsubscribe

  def self.generate_unsubscribe_token(contact_id:, account_id:)
    Rails.application.message_verifier(UNSUBSCRIBE_VERIFIER_PURPOSE).generate({
                                                                              contact_id: contact_id,
                                                                              account_id: account_id,
                                                                              generated_at: Time.current.to_i
                                                                            })
  end

  def self.verify_unsubscribe_token(token)
    Rails.application.message_verifier(UNSUBSCRIBE_VERIFIER_PURPOSE).verify(token)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  private

  def resend_compliance_headers
    return {} unless resend_channel?

    token = ResendComplianceHeaders.generate_unsubscribe_token(
      contact_id: @contact.id,
      account_id: @account.id
    )
    unsubscribe_url = "#{root_url.chomp('/')}/unsubscribe?token=#{token}"
    mailto_unsubscribe = "mailto:unsubscribe@#{@channel.email.to_s.split('@').last}?subject=unsub:#{token}"

    {
      'List-Unsubscribe' => "<#{unsubscribe_url}>, <#{mailto_unsubscribe}>",
      'List-Unsubscribe-Post' => 'List-Unsubscribe=One-Click'
    }
  end

  def resend_channel?
    @channel.respond_to?(:resend?) && @channel.resend?
  end

  def root_url
    ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
  end
end
