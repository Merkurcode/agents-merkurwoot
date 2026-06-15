class Webhooks::ResendController < ActionController::API
  def inbound
    return head :unauthorized unless valid_signature?

    dispatch_by_event_type
    head :ok
  rescue Email::ResendInboundService::ConversationNotFound => e
    Rails.logger.warn("Resend inbound: #{e.message}")
    head :ok
  rescue StandardError => e
    ChatwootExceptionTracker.new(e).capture_exception
    head :internal_server_error
  end

  def events
    return head :unauthorized unless valid_signature?

    Email::ResendEventService.new(payload).perform
    head :ok
  rescue StandardError => e
    ChatwootExceptionTracker.new(e).capture_exception
    head :internal_server_error
  end

  private

  def dispatch_by_event_type
    case payload['type']
    when 'email.received'
      Email::ResendInboundService.new(payload).perform
    when *Email::ResendEventService::HANDLED_EVENTS
      Email::ResendEventService.new(payload).perform
    else
      Rails.logger.info("Resend webhook: ignored event type '#{payload['type']}'")
    end
  end

  def payload
    @payload ||= JSON.parse(request.raw_post)
  end

  def valid_signature?
    secret = ENV.fetch('RESEND_INBOUND_WEBHOOK_SECRET', nil)
    return false if secret.blank?

    headers = {
      'svix-id' => request.headers['svix-id'],
      'svix-timestamp' => request.headers['svix-timestamp'],
      'svix-signature' => request.headers['svix-signature']
    }
    Svix::Webhook.new(secret).verify(request.raw_post, headers)
    true
  rescue Svix::WebhookVerificationError
    false
  end
end
