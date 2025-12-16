class EnrollEligibleConversationsJob < ApplicationJob
  queue_as :default

  def perform(sequence_id)
    sequence = LeadFollowUpSequence.find_by(id: sequence_id)
    return unless sequence&.active?

    Rails.logger.info "Auto-enrolling conversations for sequence #{sequence.id} (#{sequence.name})"

    # Determinar qué estados de conversación incluir
    statuses = determine_eligible_statuses(sequence)

    # Construir query base
    conversations = Conversation
                    .joins(:inbox)
                    .includes(:messages, :labels)
                    .where(
                      account_id: sequence.account_id,
                      inbox_id: sequence.inbox_id,
                      status: statuses
                    )
                    .where.not(id: ConversationFollowUp.select(:conversation_id))

    # Aplicar filtro de fecha solo si NO hay filtro de fecha configurado en la secuencia
    # Si hay filtro configurado, matches_reactivation_filters? se encargará del filtrado
    unless has_date_filter_configured?(sequence)
      conversations = conversations.where('conversations.created_at > ?', 30.days.ago)
      Rails.logger.debug "Applying default 30-day limit (no date filter configured in sequence)"
    else
      Rails.logger.debug "Skipping default date limit - sequence has custom date filter configured"
    end

    enrolled_count = 0
    skipped_count = 0

    conversations.find_each do |conversation|
      # Verificar que tenga pasos habilitados
      first_step = sequence.enabled_steps.first
      unless first_step
        skipped_count += 1
        next
      end

      # Aplicar filtros de reactivación configurados en la secuencia
      unless sequence.matches_reactivation_filters?(conversation)
        Rails.logger.debug "Skipping conversation #{conversation.id} - doesn't match reactivation filters"
        skipped_count += 1
        next
      end

      # Calcular next_action_at
      next_action_at = if first_step['type'] == 'wait'
                         calculate_wait_time(first_step)
                       else
                         Time.current
                       end

      # Verificar si el último mensaje es del contacto
      # Si es así y la secuencia debe detenerse al responder, no enrollar
      last_message = conversation.messages.reorder(created_at: :desc).first
      if sequence.settings.dig('stop_on_contact_reply') && last_message&.incoming?
        Rails.logger.debug "Skipping conversation #{conversation.id} - last message is from contact"
        skipped_count += 1
        next
      end

      # Crear ConversationFollowUp
      follow_up = ConversationFollowUp.create!(
        conversation: conversation,
        lead_follow_up_sequence: sequence,
        current_step: 0,
        next_action_at: next_action_at,
        status: 'active',
        metadata: {
          enrolled_at: Time.current,
          enrolled_via: 'auto_enroll_on_sequence_activation'
        }
      )

      # Programar job para ejecución exacta
      follow_up.schedule_job!

      enrolled_count += 1
    rescue StandardError => e
      Rails.logger.error "Failed to enroll conversation #{conversation.id}: #{e.message}"
      skipped_count += 1
    end

    Rails.logger.info "Auto-enrollment complete for sequence #{sequence.id}: " \
                      "Enrolled: #{enrolled_count}, Skipped: #{skipped_count}"
  end

  private

  def has_date_filter_configured?(sequence)
    sequence.trigger_conditions&.dig('date_filter', 'enabled') == true
  end

  def determine_eligible_statuses(sequence)
    # Por defecto, solo conversaciones abiertas o pendientes
    statuses = %i[open pending]

    # Si la configuración NO indica que debe detenerse al resolver,
    # significa que puede trabajar con conversaciones resueltas también
    # (aunque generalmente queremos evitar esto en el enrollment inicial)
    # Por ahora mantenemos solo open/pending para enrollment inicial
    statuses
  end

  def calculate_wait_time(step)
    return Time.current unless step['type'] == 'wait'

    config = step['config']
    delay = config['delay_value'].to_i

    case config['delay_type']
    when 'minutes'
      Time.current + delay.minutes
    when 'hours'
      Time.current + delay.hours
    when 'days'
      Time.current + delay.days
    else
      Time.current + delay.hours
    end
  end
end
