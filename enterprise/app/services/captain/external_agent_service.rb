class Captain::ExternalAgentService
  TIMEOUT_SECONDS = 10

  def initialize(conversation:, assistant:)
    @conversation = conversation
    @assistant = assistant
  end

  def fire(filter_run_conversation_id: nil, context_message: nil)
    message = last_incoming_message
    return unless message || context_message.present?

    payload = build_payload(message, filter_run_conversation_id: filter_run_conversation_id,
                                     context_message: context_message)
    post_to_external_agent(payload, message&.id || filter_run_conversation_id)
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: @conversation.account).capture_exception
    Rails.logger.error("[CAPTAIN][ExternalAgentService] Failed to fire webhook: #{e.message}")
  end

  private

  def last_incoming_message
    @conversation.messages.where(message_type: :incoming).last
  end

  def build_payload(message, filter_run_conversation_id: nil, context_message: nil)
    account = @conversation.account
    inbox = @conversation.inbox
    contact = @conversation.contact

    payload = {
      id: message&.id,
      event: 'message_created',
      account: { id: account.id, name: account.name },
      inbox: { id: inbox.id, name: inbox.name },
      conversation: {
        id: @conversation.display_id,
        inbox_id: inbox.id,
        status: @conversation.status,
        channel: inbox.channel_type,
        contact_inbox: { contact_id: contact.id, inbox_id: inbox.id },
        meta: { sender: { id: contact.id, name: contact.name } }
      },
      sender: {
        id: contact.id,
        name: contact.name,
        type: 'contact',
        phone_number: contact.phone_number,
        email: contact.email
      },
      content: context_message.presence || message&.content,
      content_type: 'text',
      message_type: 'incoming',
      created_at: (message&.created_at || Time.current).iso8601,
      attachments: []
    }

    payload[:filter_run_conversation_id] = filter_run_conversation_id if filter_run_conversation_id

    agent_bot = AgentBot.find_by(account_id: account.id)
    payload[:agent_bot_id] = agent_bot.id if agent_bot

    payload
  end

  def post_to_external_agent(payload, message_id)
    url = "#{ENV.fetch('EXTERNAL_CAPTAIN_AGENT_URL')}/captain_conversation_webhook"

    headers = build_headers(message_id)

    connection = Faraday.new(url: url) do |f|
      f.options.timeout = TIMEOUT_SECONDS
      f.adapter Faraday.default_adapter
    end

    response = connection.post do |req|
      req.headers.merge!(headers)
      req.body = payload.to_json
    end

    Rails.logger.info("[CAPTAIN][ExternalAgentService] Webhook fired to #{url}, status: #{response.status}")
  end

  def build_headers(message_id)
    headers = {
      'Content-Type' => 'application/json',
      'X-Idempotency-Key' => message_id.to_s
    }
    token = ENV.fetch('EXTERNAL_CAPTAIN_AGENT_TOKEN', nil)
    headers['Authorization'] = "Bearer #{token}" if token.present?
    headers
  end
end
