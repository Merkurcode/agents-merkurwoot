class ConversationAiUsages::ReportService
  pattr_initialize [:conversation!, :params!]

  def perform
    attrs = params[:conversation_attributes] || {}
    usage = conversation.conversation_ai_usage || conversation.build_conversation_ai_usage
    usage.assign_attributes(
      account:              conversation.account,
      thread_id:            params[:thread_id],
      ai_cost_usd:          attrs[:ai_cost_usd],
      ai_input_tokens:      attrs[:ai_input_tokens],
      ai_output_tokens:     attrs[:ai_output_tokens],
      ai_llm_calls:         attrs[:ai_llm_calls],
      ai_graph_invocations: attrs[:ai_graph_invocations],
      ai_avg_latency_ms:    attrs[:ai_avg_latency_ms],
      ai_p95_latency_ms:    attrs[:ai_p95_latency_ms],
      ai_error_count:       attrs[:ai_error_count],
      ai_duration_seconds:  attrs[:ai_duration_seconds],
      ai_started_at:        attrs[:ai_started_at],
      ai_models_used:       attrs[:ai_models_used],
      ai_cost_by_model:     attrs[:ai_cost_by_model] || {}
    )
    usage.save!
  end
end
