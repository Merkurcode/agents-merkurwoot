class Api::V1::Accounts::Captain::AssistantFilterRunsController < Api::V1::Accounts::BaseController
  before_action :current_account
  before_action -> { check_authorization(Captain::AssistantFilterRun) }
  before_action :set_run, only: [:show]

  def index
    @runs = Current.account.captain_assistant_filter_runs
                   .includes(assistant_filter: :captain_assistant)
                   .then { |q| params[:assistant_filter_id].present? ? q.where(assistant_filter_id: params[:assistant_filter_id]) : q }
                   .order(created_at: :desc)
                   .page(params[:page]).per(25)
  end

  def show; end

  def create
    @run = Current.account.captain_assistant_filter_runs.new(run_params)
    @run.triggered_by = current_user

    if @run.save
      schedule_or_run_immediately
      render :show, status: :created
    else
      render json: { error: @run.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  private

  def set_run
    @run = Current.account.captain_assistant_filter_runs
                  .includes(run_conversations: :conversation)
                  .find(params[:id])
  end

  def run_params
    params.require(:filter_run).permit(:assistant_filter_id, :scheduled_at, :message)
  end

  def schedule_or_run_immediately
    if @run.scheduled_at.present? && @run.scheduled_at > Time.current
      Captain::AssistantFilterRunJob.set(wait_until: @run.scheduled_at).perform_later(@run)
    else
      Captain::AssistantFilterRunJob.perform_later(@run)
    end
  end
end
