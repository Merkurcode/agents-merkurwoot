# frozen_string_literal: true

class PipelineBoard
  RESOURCE_STRATEGIES = {
    'contact' => {
      filter_service: 'Contacts::FilterService',
      filter_result_key: :contacts,
      search_fields: %w[contacts.name contacts.email contacts.phone_number]
    }
  }.freeze

  def initialize(account:, user:, account_user:, pipeline_type:, params:)
    @account = account
    @user = user
    @account_user = account_user
    @pipeline_type = pipeline_type
    @params = params
  end

  def columns
    @account.pipeline_statuses.where(pipeline_type: @pipeline_type).map do |status|
      {
        id: status.id,
        name: status.name,
        position: status.position,
        items: items_scope.where(pipeline_status_id: status.id)
      }
    end
  end

  private

  def strategy
    RESOURCE_STRATEGIES[@pipeline_type]
  end

  def items_scope
    if @params[:payload].present?
      strategy[:filter_service].constantize
                               .new(@account, @user, @params)
                               .perform[strategy[:filter_result_key]]
    else
      apply_search(base_scope)
    end
  end

  def base_scope
    case @pipeline_type
    when 'contact' then contact_base_scope
    end
  end

  def contact_base_scope
    scope = @account.contacts.resolved_contacts(use_crm_v2: @account.feature_enabled?('crm_v2'))
    scope = supervisor_filtered_contacts(scope) if @account_user&.supervisor?
    @params[:labels].present? ? scope.tagged_with(@params[:labels], any: true) : scope
  end

  def apply_search(scope)
    return scope if @params[:q].blank?

    query = "%#{@params[:q].strip}%"
    conditions = strategy[:search_fields].map { |f| "#{f} ILIKE :q" }.join(' OR ')
    scope.where(conditions, q: query)
  end

  def supervisor_filtered_contacts(scope)
    assignee_ids = @account_user.all_subordinate_user_ids + [@user.id]
    contact_ids = @account.conversations.where(assignee_id: assignee_ids).pluck(:contact_id).uniq
    scope.where(id: contact_ids)
  end
end
