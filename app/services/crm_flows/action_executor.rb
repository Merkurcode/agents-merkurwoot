module CrmFlows
  class ActionExecutor
    CRM_ACTIONS = %w[create_lead create_opportunity create_task create_event add_crm_tag add_note].freeze
    CHATWOOT_ACTIONS = %w[assign_chatwoot_agent add_chatwoot_label].freeze

    IDEMPOTENCY_STRATEGIES = {
      'create_lead' => :check_external_id,
      'create_opportunity' => :check_external_id,
      'create_event' => :check_external_id,
      'add_crm_tag' => :idempotent_by_nature,
      'create_task' => :none,
      'add_note' => :none
    }.freeze

    def initialize(account:, contact:, conversation:, metadata: {})
      @account = account
      @contact = contact
      @conversation = conversation
      @metadata = metadata
      @crm_hooks = Integrations::Hook.where(account_id: account.id).crm_hooks.enabled
    end

    def execute(actions)
      results = []
      (actions || []).sort_by { |a| a['order'] || 0 }.each do |action|
        if CHATWOOT_ACTIONS.include?(action['action'])
          results << execute_chatwoot_action(action)
        elsif CRM_ACTIONS.include?(action['action'])
          results.concat(execute_crm_action(action))
        end
      end
      results
    end

    private

    def execute_chatwoot_action(action)
      case action['action']
      when 'assign_chatwoot_agent' then assign_agent(action)
      when 'add_chatwoot_label'    then add_label(action)
      else { action: action['action'], status: 'failed', error: 'Unknown chatwoot action', type: 'chatwoot' }
      end
    end

    def assign_agent(action)
      agent_id = action.dig('params', 'agent_id')
      return { action: 'assign_chatwoot_agent', status: 'failed', error: 'agent_id missing', type: 'chatwoot' } if agent_id.blank?

      @conversation.update!(assignee_id: agent_id)
      { action: 'assign_chatwoot_agent', status: 'success', type: 'chatwoot' }
    rescue StandardError => e
      { action: 'assign_chatwoot_agent', status: 'failed', error: e.message, type: 'chatwoot' }
    end

    def add_label(action)
      label_title = action.dig('params', 'label')
      return { action: 'add_chatwoot_label', status: 'failed', error: 'label missing', type: 'chatwoot' } if label_title.blank?

      existing = @conversation.labels || []
      @conversation.labels = (existing + [label_title]).uniq
      @conversation.save!
      { action: 'add_chatwoot_label', status: 'success', type: 'chatwoot' }
    rescue StandardError => e
      { action: 'add_chatwoot_label', status: 'failed', error: e.message, type: 'chatwoot' }
    end

    def execute_crm_action(action)
      @crm_hooks.map { |hook| execute_single_crm_action(hook, action) }
    end

    def execute_single_crm_action(hook, action)
      action_name = action['action']
      crm_name = hook.app_id

      strategy = IDEMPOTENCY_STRATEGIES[action_name]
      if strategy == :check_external_id && external_id_exists?(hook, action_name)
        return { action: action_name, crm: crm_name, status: 'skipped', reason: 'already_exists', type: 'crm' }
      end

      processor = build_processor(hook)
      unless processor
        return { action: action_name, crm: crm_name, status: 'skipped', reason: 'unsupported', type: 'crm' }
      end

      params = build_params(action)
      result = processor.execute_action(action_name, params)

      if result[:success]
        eid = result[:lead_id] || result[:task_id] || result[:event_id] || result[:opportunity_id] || result[:note_id]
        { action: action_name, crm: crm_name, status: 'success', external_id: eid, type: 'crm' }
      else
        { action: action_name, crm: crm_name, status: 'failed', error: result[:error], type: 'crm' }
      end
    rescue StandardError => e
      Rails.logger.error "CrmFlows::ActionExecutor (#{action['action']}/#{hook.app_id}): #{e.message}"
      { action: action['action'], crm: hook.app_id, status: 'failed', error: e.message, type: 'crm' }
    end

    def external_id_exists?(hook, action_name)
      case action_name
      when 'create_lead'
        @contact.additional_attributes&.dig('external', "#{hook.app_id}_lead_id").present?
      when 'create_opportunity'
        @contact.additional_attributes&.dig('external', "#{hook.app_id}_opportunity_id").present?
      else
        false
      end
    end

    def build_processor(hook)
      case hook.app_id
      when 'zoho'       then Crm::Zoho::ProcessorService.new(hook)
      when 'salesforce' then Crm::Salesforce::ProcessorService.new(hook)
      else nil
      end
    rescue StandardError
      nil
    end

    def build_params(action)
      (action['params'] || {}).merge(
        'contact_id' => @contact.id,
        'metadata' => @metadata
      )
    end
  end
end
