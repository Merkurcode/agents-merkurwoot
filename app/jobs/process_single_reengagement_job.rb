# frozen_string_literal: true

class ProcessSingleReengagementJob < ApplicationJob
  queue_as :scheduled_jobs
  sidekiq_options retry: 0

  MAX_ATTEMPT_RETRIES = 3
  RETRY_BACKOFF = 5.minutes

  def perform(reengagement_id)
    reengagement = ConversationReengagement.find_by(id: reengagement_id)

    unless reengagement&.status == 'active'
      reengagement&.clear_processing!
      return
    end

    if reengagement.conversation.resolved?
      reengagement.cancel!(reason: 'cancelled_reply')
      return
    end

    AgentBots::ReengagementService.new(reengagement).execute
  rescue StandardError => e
    Rails.logger.error "[ReengagementJob] failed id=#{reengagement_id} attempt=#{reengagement&.current_attempt}: #{e.class} — #{e.message}"
    return unless reengagement

    reengagement.increment_attempt_retries!

    if reengagement.attempt_retry_count >= MAX_ATTEMPT_RETRIES
      Rails.logger.warn "[ReengagementJob] max retries reached for id=#{reengagement_id}, skipping attempt #{reengagement.current_attempt}"
      reengagement.skip_attempt!
    else
      reengagement.update!(processing_started_at: nil, next_fire_at: RETRY_BACKOFF.from_now)
    end
  end
end
