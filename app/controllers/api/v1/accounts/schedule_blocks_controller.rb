# frozen_string_literal: true

class Api::V1::Accounts::ScheduleBlocksController < Api::V1::Accounts::BaseController
  before_action :fetch_agent
  before_action :authorize_access!

  def index
    @schedule_blocks = @account_user.schedule_blocks.order(:day_of_week, :start_hour, :start_minutes)
    render json: @schedule_blocks
  end

  def create
    @schedule_block = @account_user.schedule_blocks.build(schedule_block_params)
    if @schedule_block.save
      render json: @schedule_block, status: :created
    else
      render json: { errors: @schedule_block.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    @schedule_block = @account_user.schedule_blocks.find(params[:id])
    if @schedule_block.update(schedule_block_params)
      render json: @schedule_block
    else
      render json: { errors: @schedule_block.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @schedule_block = @account_user.schedule_blocks.find(params[:id])
    @schedule_block.destroy
    head :no_content
  end

  private

  def fetch_agent
    agent_user = Current.account.users.find(params[:agent_id])
    @account_user = Current.account.account_users.find_by!(user_id: agent_user.id)
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Agent not found' }, status: :not_found
  end

  def authorize_access!
    return if Current.account_user.administrator? || Current.account_user.supervisor?
    return if Current.account_user.id == @account_user.id

    render json: { error: 'Unauthorized' }, status: :forbidden
  end

  def schedule_block_params
    params.require(:schedule_block).permit(:day_of_week, :start_hour, :start_minutes, :end_hour, :end_minutes, :reason)
  end
end
