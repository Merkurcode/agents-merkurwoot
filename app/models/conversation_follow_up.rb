class ConversationFollowUp < ApplicationRecord
  belongs_to :conversation
  belongs_to :lead_follow_up_sequence

  validates :conversation_id, uniqueness: true
  validates :status, presence: true, inclusion: { in: %w[active paused completed cancelled failed] }

  scope :active, -> { where(status: 'active') }
  scope :pending_execution, -> { active.where('next_action_at <= ?', Time.current) }

  def mark_as_completed!(reason = nil)
    update!(
      status: 'completed',
      metadata: (metadata || {}).merge(
        completion_reason: reason,
        completed_at: Time.current
      )
    )
  end

  def mark_as_cancelled!(reason = nil)
    update!(
      status: 'cancelled',
      metadata: (metadata || {}).merge(
        cancellation_reason: reason,
        cancelled_at: Time.current
      )
    )
  end

  def mark_as_failed!(error_message)
    update!(
      status: 'failed',
      metadata: (metadata || {}).merge(
        failure_reason: error_message,
        failed_at: Time.current
      )
    )
  end

  def pause!
    update!(status: 'paused')
  end

  def resume!
    update!(status: 'active')
  end

  def increment_retry_count!
    current_retry = metadata&.dig('retry_count') || 0
    update!(
      metadata: (metadata || {}).merge(
        retry_count: current_retry + 1
      )
    )
  end

  def retry_count
    metadata&.dig('retry_count') || 0
  end
end
