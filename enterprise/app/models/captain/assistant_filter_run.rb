class Captain::AssistantFilterRun < ApplicationRecord
  self.table_name = 'captain_assistant_filter_runs'

  belongs_to :account
  belongs_to :assistant_filter, class_name: 'Captain::AssistantFilter'
  belongs_to :triggered_by, class_name: 'User', optional: true, foreign_key: :triggered_by_id
  has_many :run_conversations, class_name: 'Captain::AssistantFilterRunConversation',
                               foreign_key: :filter_run_id, dependent: :destroy

  enum :status, { pending: 0, running: 1, completed: 2, failed: 3 }

  validates :account, presence: true
  validates :assistant_filter, presence: true

  scope :scheduled, -> { where(status: :pending).where.not(scheduled_at: nil) }
end
