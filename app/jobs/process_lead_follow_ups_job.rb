class ProcessLeadFollowUpsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    ConversationFollowUp
      .pending_execution
      .find_each(batch_size: 100) do |follow_up|
        process_follow_up(follow_up)
      end
  end

  private

  def process_follow_up(follow_up)
    LeadRetargeting::SendFollowUpService.new(follow_up).execute
  rescue StandardError => e
    Rails.logger.error "Failed to process follow-up #{follow_up.id}: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")

    follow_up.increment_retry_count!

    if follow_up.retry_count >= 3
      follow_up.mark_as_failed!("Max retries exceeded: #{e.message}")
    end
  end
end
