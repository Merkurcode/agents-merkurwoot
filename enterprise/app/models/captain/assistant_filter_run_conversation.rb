class Captain::AssistantFilterRunConversation < ApplicationRecord
  self.table_name = 'captain_assistant_filter_run_conversations'

  belongs_to :filter_run, class_name: 'Captain::AssistantFilterRun'
  belongs_to :conversation, class_name: '::Conversation'

  enum :status, { pending: 0, success: 1, failed: 2 }

  validates :filter_run, presence: true
  validates :conversation, presence: true
end
