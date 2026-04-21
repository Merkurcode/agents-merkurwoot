class Captain::AssistantFilter < ApplicationRecord
  self.table_name = 'captain_assistant_filters'

  belongs_to :account
  belongs_to :captain_assistant, class_name: 'Captain::Assistant'
  has_many :runs, class_name: 'Captain::AssistantFilterRun', foreign_key: :assistant_filter_id, dependent: :destroy_async

  validates :name, presence: true
  validates :filters, presence: true

  scope :active, -> { where(active: true) }
  scope :for_account, ->(account_id) { where(account_id: account_id) }
end
