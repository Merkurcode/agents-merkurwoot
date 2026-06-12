class Email::SendOnEmailService < Base::SendOnChannelService
  private

  def channel_class
    Channel::Email
  end

  def perform_reply
    return unless message.email_notifiable_message?

    reply_mail = ConversationReplyMailer.with(account: message.account).email_reply(message).deliver_now

    if reply_mail.is_a?(Mail::Message)
      Rails.logger.info("Email message #{message.id} sent with source_id: #{reply_mail.message_id}")
      message.update(source_id: reply_mail.message_id)
    else
      smtp_error = "SMTP delivery failed: #{reply_mail.class.name} - #{reply_mail.respond_to?(:message) ? reply_mail.message : reply_mail.inspect}"
      Rails.logger.error("Email message #{message.id} failed: #{smtp_error}")
      Messages::StatusUpdateService.new(message, 'failed', smtp_error).perform
    end
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: message.account).capture_exception
    Messages::StatusUpdateService.new(message, 'failed', e.message).perform
  end
end
