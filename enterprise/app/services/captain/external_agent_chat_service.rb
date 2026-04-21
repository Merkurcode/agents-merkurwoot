class Captain::ExternalAgentChatService
  TIMEOUT_SECONDS = 30

  def initialize(assistant:, message_content:, message_history:)
    @assistant = assistant
    @message_content = message_content
    @message_history = message_history
  end

  def chat
    payload = {
      message_content: @message_content,
      message_history: @message_history,
      assistant: {
        id: @assistant.id,
        name: @assistant.name,
        description: @assistant.description
      }
    }

    url = "#{ENV.fetch('EXTERNAL_CAPTAIN_AGENT_URL')}/playground"
    token = ENV.fetch('EXTERNAL_CAPTAIN_AGENT_TOKEN', nil)

    connection = Faraday.new(url: url) do |f|
      f.options.timeout = TIMEOUT_SECONDS
      f.adapter Faraday.default_adapter
    end

    response = connection.post do |req|
      req.headers['Content-Type'] = 'application/json'
      req.headers['Authorization'] = "Bearer #{token}" if token.present?
      req.body = payload.to_json
    end

    JSON.parse(response.body)
  end
end
