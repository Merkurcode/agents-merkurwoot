class Api::V1::Accounts::Captain::AssistantFiltersController < Api::V1::Accounts::BaseController
  before_action :current_account
  before_action -> { check_authorization(Captain::AssistantFilter) }
  before_action :set_filter, only: [:update, :destroy]

  def index
    @filters = Current.account.captain_assistant_filters.includes(:captain_assistant).order(:created_at)
  end

  def create
    @filter = Current.account.captain_assistant_filters.new(filter_params)
    if @filter.save
      render :show, status: :created
    else
      render json: { error: @filter.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def update
    if @filter.update(filter_params)
      render :show
    else
      render json: { error: @filter.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def destroy
    @filter.destroy
    head :no_content
  end

  private

  def set_filter
    @filter = Current.account.captain_assistant_filters.find(params[:id])
  end

  def filter_params
    permitted = params.require(:assistant_filter).permit(:name, :captain_assistant_id, :active)
    permitted[:filters] = params[:assistant_filter][:filters].map(&:to_unsafe_h) if params[:assistant_filter].key?(:filters)
    permitted
  end
end
