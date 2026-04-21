module Enterprise::Api::V1::Accounts::ConversationsController
  extend ActiveSupport::Concern

  def inbox_assistant
    assistant = @conversation.inbox.captain_assistant

    if assistant
      render json: { assistant: { id: assistant.id, name: assistant.name } }
    else
      render json: { assistant: nil }
    end
  end

  def reporting_events
    @reporting_events = @conversation.reporting_events.order(created_at: :asc)
  end

  def captain_activities
    run_convs = Captain::AssistantFilterRunConversation
                  .where(conversation: @conversation)
                  .includes(filter_run: [:triggered_by, { assistant_filter: :captain_assistant }])
                  .order(created_at: :desc)
                  .limit(50)

    render json: {
      activities: run_convs.map do |rc|
        filter_run = rc.filter_run
        filter = filter_run.assistant_filter
        {
          id: rc.id,
          status: rc.status,
          error_message: rc.error_message,
          processed_at: rc.processed_at,
          created_at: rc.created_at,
          filter_name: filter.name,
          assistant_name: filter.captain_assistant&.name,
          message: filter_run.message,
          triggered_by: filter_run.triggered_by&.name,
          scheduled_at: filter_run.scheduled_at
        }
      end
    }
  end

  def permitted_update_params
    super.merge(params.permit(:sla_policy_id))
  end

  private

  def copilot_params
    params.permit(:previous_history, :message, :assistant_id)
  end
end
