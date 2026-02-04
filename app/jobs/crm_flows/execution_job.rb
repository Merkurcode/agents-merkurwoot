module CrmFlows
  class ExecutionJob < ApplicationJob
    queue_as :default
    retry_on StandardError, attempts: 3, wait: 5.seconds

    ACTION_LABELS = {
      'create_lead'              => 'Lead creado',
      'create_opportunity'       => 'Oportunidad creada',
      'create_task'              => 'Tarea creada',
      'create_event'             => 'Evento creado',
      'add_crm_tag'              => 'Etiqueta añadida',
      'add_note'                 => 'Nota añadida',
      'assign_chatwoot_agent'    => 'Asignado a asesor',
      'add_chatwoot_label'       => 'Label añadido'
    }.freeze

    def perform(flow_id:, conversation_id:, contact_id:, metadata:, idempotency_key:)
      flow         = CrmFlow.find(flow_id)
      contact      = Contact.find(contact_id)
      conversation = Conversation.find_by(id: conversation_id)

      results = ActionExecutor.new(
        account:      flow.account,
        contact:      contact,
        conversation: conversation,
        metadata:     metadata.stringify_keys
      ).execute(flow.actions)

      status = compute_status(results)

      execution = CrmFlowExecution.create!(
        crm_flow:      flow,
        conversation:  conversation,
        contact:       contact,
        trigger_type:  flow.trigger_type,
        status:        status,
        results:       results,
        metadata:      metadata,
        idempotency_key: idempotency_key
      )

      IdempotencyService.store_completed(idempotency_key, response: {
        execution_id: execution.id,
        status:       status,
        results:      results
      })

      create_activity_message(conversation, flow, results) if conversation
    rescue StandardError => e
      IdempotencyService.store_failed(idempotency_key, error: e.message) if idempotency_key
      raise
    end

    private

    def compute_status(results)
      statuses = results.map { |r| r[:status] || r['status'] }
      return 'failed' if statuses.all? { |s| s == 'failed' }
      return 'success' if statuses.all? { |s| %w[success skipped].include?(s) }

      'partial'
    end

    def create_activity_message(conversation, flow, results)
      lines  = results.map { |r| format_line(r) }.compact
      html   = "<b>CRM Flow &quot;#{flow.name}&quot;:</b><br>#{lines.join('<br>')}"
      conversation.messages.create!(content: html, message_type: :activity, content_type: :input_text)
    rescue StandardError => e
      Rails.logger.error "CrmFlows::ExecutionJob activity message: #{e.message}"
    end

    def format_line(r)
      action = r[:action] || r['action']
      status = r[:status] || r['status']
      crm    = r[:crm]    || r['crm']
      error  = r[:error]  || r['error']

      label  = ACTION_LABELS[action] || action.to_s.humanize
      suffix = crm ? " en #{crm.capitalize}" : ''

      case status
      when 'success' then "✓ #{label}#{suffix}"
      when 'skipped' then "● #{label}#{suffix} — ya existía"
      when 'failed'  then "✗ #{label}#{suffix} — #{error}"
      end
    end
  end
end
