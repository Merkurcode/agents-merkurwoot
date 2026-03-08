class Api::V1::Accounts::Captain::AssistantFilterRunConversationsController < Api::V1::Accounts::BaseController
  before_action :current_account
  before_action -> { check_authorization(Captain::AssistantFilterRunConversation) }
  before_action :set_run_conversation

  def update
    status = params[:status].to_s
    unless %w[success failed].include?(status)
      return render json: { error: 'Invalid status' }, status: :unprocessable_entity
    end

    @run_conversation.update!(
      status: status,
      error_message: params[:error_message],
      processed_at: Time.current
    )

    head :no_content
  end

  private

  def set_run_conversation
    @run_conversation = Captain::AssistantFilterRunConversation
                          .joins(filter_run: :account)
                          .where(accounts: { id: Current.account.id })
                          .find(params[:id])
  end
end
