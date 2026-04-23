# frozen_string_literal: true

class Task < ApplicationRecord
  # Associations
  belongs_to :account
  belongs_to :creator, class_name: 'User'
  belongs_to :entity, polymorphic: true, optional: true
  belongs_to :assignee, class_name: 'User', optional: true
  belongs_to :ai_agent, class_name: 'Captain::Assistant', optional: true

  # Enums
  enum status: {
    pending: 0,
    in_progress: 1,
    completed: 2,
    cancelled: 3
  }

  enum action_type: {
    general: 0,
    schedule_appointment: 1,
    send_message: 3,
    assign_conversation: 4
  }

  # Validations
  validates :title, presence: true
  validates :status, presence: true
  validate :only_one_agent_type

  # Scopes
  scope :by_status, ->(status) { where(status: status) }
  scope :by_entity, ->(type, id) { where(entity_type: type, entity_id: id) }
  scope :due_for_execution, -> { pending.where('scheduled_at <= ?', Time.current).where.not(scheduled_at: nil) }

  private

  def only_one_agent_type
    return unless assignee_id.present? && ai_agent_id.present?

    errors.add(:base, 'Cannot assign both a human agent and an AI agent')
  end
end
