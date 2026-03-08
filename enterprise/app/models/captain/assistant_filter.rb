class Captain::AssistantFilter < ApplicationRecord
  self.table_name = 'captain_assistant_filters'

  belongs_to :account
  belongs_to :captain_assistant, class_name: 'Captain::Assistant'

  validates :name, presence: true
  validates :filters, presence: true

  scope :active, -> { where(active: true) }
  scope :for_account, ->(account_id) { where(account_id: account_id) }

  validate :no_filter_conflicts

  private

  def no_filter_conflicts
    other_filters = account.captain_assistant_filters.active.where.not(id: id)
    return if other_filters.empty?
    return if filters.blank?

    my_ids = Captain::ConversationFilterMatcher.matching_ids(filters: filters, account: account)
    return if my_ids.empty?

    other_filters.each do |other|
      conflicting = Captain::ConversationFilterMatcher.matching_ids(filters: other.filters, account: account) & my_ids
      next if conflicting.empty?

      errors.add(:filters, I18n.t('captain.assistant_filter.conflict', name: other.name,
                                                                        assistant: other.captain_assistant.name))
      return
    end
  end
end
