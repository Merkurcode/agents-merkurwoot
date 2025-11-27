class Api::V1::Accounts::Conversations::AssignmentsController < Api::V1::Accounts::Conversations::BaseController
  # assigns agent/team to a conversation
  def create
    if params.key?(:assignee_id)
      set_agent
    elsif params.key?(:team_id)
      set_team
    else
      render json: nil
    end
  end

  private

  def set_agent
    @agent = Current.account.users.find_by(id: params[:assignee_id])
    @conversation.assignee = @agent
    @conversation.save!
    trigger_whatsapp_group_creation
    render_agent
  end

  def render_agent
    if @agent.nil?
      render json: nil
    else
      render partial: 'api/v1/models/agent', formats: [:json], locals: { resource: @agent }
    end
  end

  def set_team
    @team = Current.account.teams.find_by(id: params[:team_id])
    @conversation.update!(team: @team)
    render json: @team
  end

  def trigger_whatsapp_group_creation
    return unless whatsapp_group_enabled?

    group_options = {
      group_name: params[:group_name],
      welcome_message: params[:welcome_message]
    }.compact

    Whatsapp::CreateGroupJob.perform_later(@conversation.id, group_options)
  end

  def whatsapp_group_enabled?
    return false unless @agent.present?
    return false unless Current.account.feature_enabled?(:whatsapp_groups)

    @conversation.inbox.auto_assignment_config&.dig('assignment_type') == 'group' &&
      @agent.phone_number.present? &&
      @conversation.contact&.phone_number.present?
  end
end
