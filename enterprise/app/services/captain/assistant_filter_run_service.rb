class Captain::AssistantFilterRunService
  def initialize(filter_run:)
    @run = filter_run
    @filter = filter_run.assistant_filter
    @assistant = @filter.captain_assistant
    @account = filter_run.account
  end

  def perform
    @run.update!(status: :running)

    conversation_ids = Captain::ConversationFilterMatcher.matching_ids(
      filters: @filter.filters,
      account: @account
    )

    @run.update!(conversations_total: conversation_ids.count)

    conversation_ids.each { |id| process_conversation(id) }

    @run.update!(status: :completed)
  rescue StandardError => e
    @run.update!(status: :failed)
    Rails.logger.error("[Captain][FilterRunService] Run #{@run.id} failed: #{e.message}")
    raise e
  end

  private

  def process_conversation(conversation_id)
    conversation = Conversation.find(conversation_id)
    run_conv = @run.run_conversations.create!(conversation: conversation)

    Captain::ExternalAgentService.new(
      conversation: conversation,
      assistant: @assistant
    ).fire(filter_run_conversation_id: run_conv.id, context_message: @run.message)

    @run.increment!(:conversations_processed)
  rescue StandardError => e
    Rails.logger.error("[Captain][FilterRunService] Conversation #{conversation_id} failed: #{e.message}")
    run_conv&.update!(status: :failed, error_message: e.message, processed_at: Time.current)
    @run.increment!(:conversations_processed)
  end
end
