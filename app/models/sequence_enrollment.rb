class SequenceEnrollment < ApplicationRecord
  belongs_to :conversation
  belongs_to :lead_follow_up_sequence
  has_many :enrollment_events, dependent: :destroy
  has_one :active_follow_up, class_name: 'ConversationFollowUp', dependent: :nullify

  validates :status, presence: true, inclusion: { in: %w[active completed cancelled failed] }
  validates :enrolled_at, presence: true

  scope :active, -> { where(status: 'active') }
  scope :completed, -> { where(status: 'completed') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :failed, -> { where(status: 'failed') }

  # Mark enrollment as completed
  def complete!(reason = nil)
    update!(
      status: 'completed',
      completed_at: Time.current,
      completion_reason: reason
    )

    # Create completion event
    create_event(
      event_type: 'completed',
      metadata: {
        completion_reason: reason,
        total_steps: current_step,
        duration_seconds: (Time.current - enrolled_at).to_i
      }
    )
  end

  # Mark enrollment as cancelled
  def cancel!(reason = nil)
    update!(
      status: 'cancelled',
      completed_at: Time.current,
      completion_reason: reason
    )

    # Create cancellation event
    create_event(
      event_type: 'cancelled',
      metadata: {
        cancellation_reason: reason,
        steps_completed: current_step
      }
    )
  end

  # Mark enrollment as failed
  def fail!(error_message)
    update!(
      status: 'failed',
      completed_at: Time.current,
      completion_reason: error_message
    )

    # Create failure event
    create_event(
      event_type: 'failed',
      metadata: {
        error_message: error_message,
        steps_completed: current_step
      }
    )
  end

  # Create an event for this enrollment
  def create_event(event_type:, step_id: nil, step_index: nil, metadata: {})
    enrollment_events.create!(
      conversation: conversation,
      lead_follow_up_sequence: lead_follow_up_sequence,
      event_type: event_type,
      step_id: step_id,
      step_index: step_index,
      occurred_at: Time.current,
      metadata: metadata
    )
  end

  # Get timeline of events for this enrollment
  def timeline
    enrollment_events.order(occurred_at: :asc)
  end

  # Check if enrollment is active
  def active?
    status == 'active'
  end

  # Check if enrollment is finished (completed, cancelled, or failed)
  def finished?
    %w[completed cancelled failed].include?(status)
  end

  # Get duration in seconds
  def duration
    return nil unless completed_at

    (completed_at - enrolled_at).to_i
  end
end
