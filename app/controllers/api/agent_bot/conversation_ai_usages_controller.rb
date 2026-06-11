# frozen_string_literal: true

class Api::AgentBot::ConversationAiUsagesController < ApplicationController
  before_action :authenticate_agent_bot!
  before_action :set_conversation

  def create
    ConversationAiUsages::ReportService.new(conversation: @conversation, params: ai_usage_params).perform
    render json: { thread_id: @conversation.ai_thread_id }, status: :created
  end

  private

  def authenticate_agent_bot!
    token = request.headers['X-Bot-Token'] || params[:bot_token]
    access_token = AccessToken.find_by(token: token) if token.present?
    @current_agent_bot = access_token&.owner if access_token&.owner.is_a?(AgentBot)
    render json: { error: 'Unauthorized' }, status: :unauthorized unless @current_agent_bot
  end

  def set_conversation
    @conversation = Conversation.find_by(display_id: params[:conversation_id], account_id: @current_agent_bot.account_id)
    return render json: { error: 'Conversation not found' }, status: :not_found unless @conversation
  end

  def ai_usage_params
    permitted = params.permit(
      :thread_id,
      conversation_attributes: [
        :ai_cost_usd, :ai_input_tokens, :ai_output_tokens, :ai_llm_calls,
        :ai_graph_invocations, :ai_avg_latency_ms, :ai_p95_latency_ms,
        :ai_error_count, :ai_duration_seconds, :ai_started_at, :ai_models_used
      ]
    )
    cost_by_model = params.dig(:conversation_attributes, :ai_cost_by_model)
    permitted[:conversation_attributes]&.merge!(ai_cost_by_model: cost_by_model.to_unsafe_h) if cost_by_model.present?
    permitted
  end
end
