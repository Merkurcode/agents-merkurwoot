class LeadFollowUpListener < BaseListener
  def conversation_created(event)
    conversation = event.data[:conversation]

    return unless conversation.inbox.inbox_type == 'Whatsapp'

    enroll_in_active_sequence(conversation)
  end

  def message_created(event)
    message = event.data[:message]
    conversation = message.conversation
    follow_up = conversation.conversation_follow_up

    return unless follow_up

    if message.incoming?
      pause_sequence_on_contact_reply(follow_up)
    elsif message.outgoing? && message.sender.is_a?(User)
      reset_sequence_on_agent_reply(follow_up)
    end
  end

  private

  def enroll_in_active_sequence(conversation)
    sequence = LeadFollowUpSequence
               .active
               .where(account_id: conversation.account_id, inbox_id: conversation.inbox_id)
               .first

    return unless sequence

    return if conversation.conversation_follow_up.present?

    first_step = sequence.enabled_steps.first
    return unless first_step

    next_action_at = if first_step['type'] == 'wait'
                       calculate_wait_time(first_step)
                     else
                       Time.current
                     end

    follow_up = ConversationFollowUp.create!(
      conversation: conversation,
      lead_follow_up_sequence: sequence,
      current_step: 0,
      next_action_at: next_action_at,
      status: 'active'
    )

    Rails.logger.info "Enrolled conversation #{conversation.id} in sequence #{sequence.id}"

    # Check if contact has already replied (race condition fix)
    if sequence.settings.dig('stop_on_contact_reply') && conversation.messages.incoming.exists?
      follow_up.mark_as_completed!('Contact replied')
      Rails.logger.info "Immediately completed follow-up #{follow_up.id} - contact already replied"
    else
      # Schedule job for exact timing
      follow_up.schedule_job!
    end
  rescue StandardError => e
    Rails.logger.error "Failed to enroll conversation #{conversation.id}: #{e.message}"
  end

  def pause_sequence_on_contact_reply(follow_up)
    return unless follow_up.status == 'active'

    if follow_up.lead_follow_up_sequence.settings.dig('stop_on_contact_reply')
      follow_up.cancel_job!
      follow_up.mark_as_completed!('Contact replied')
      Rails.logger.info "Completed follow-up #{follow_up.id} - contact replied"
    end
  end

  def reset_sequence_on_agent_reply(follow_up)
    return unless follow_up.status == 'active'

    first_step = follow_up.lead_follow_up_sequence.enabled_steps.first
    return unless first_step

    next_action_at = if first_step['type'] == 'wait'
                       calculate_wait_time(first_step)
                     else
                       Time.current
                     end

    follow_up.update!(
      current_step: 0,
      next_action_at: next_action_at,
      metadata: (follow_up.metadata || {}).merge(
        reset_at: Time.current,
        reset_count: (follow_up.metadata&.dig('reset_count') || 0) + 1
      )
    )

    # Reschedule job for the new next_action_at
    follow_up.schedule_job!

    Rails.logger.info "Reset follow-up #{follow_up.id} - agent replied"
  end

  def calculate_wait_time(step)
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
