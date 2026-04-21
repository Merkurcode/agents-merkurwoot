class Captain::ConversationFilterMatcher < Conversations::FilterService
  def initialize(params, account)
    super(params, nil, account)
  end

  # Returns the first matching Captain::Assistant for the given conversation, or nil.
  def self.match(conversation)
    account = conversation.account
    filters = account.captain_assistant_filters.active.includes(:captain_assistant).order(:created_at)

    filters.each do |assistant_filter|
      next if assistant_filter.filters.blank?

      params = { payload: normalize(assistant_filter.filters) }
      matcher = new(params, account)
      return assistant_filter.captain_assistant if matcher.matches?(conversation)
    rescue StandardError => e
      Rails.logger.error("[Captain][ConversationFilterMatcher] Error evaluating filter #{assistant_filter.id}: #{e.message}")
      next
    end

    nil
  end

  # Returns conversation IDs matching the given filter conditions for an account.
  def self.matching_ids(filters:, account:)
    params = { payload: normalize(filters) }
    new(params, account).matching_ids
  rescue StandardError => e
    Rails.logger.error("[Captain][ConversationFilterMatcher] Error getting matching IDs: #{e.message}")
    []
  end

  def self.matching_count(filters:, account:)
    params = { payload: normalize(filters) }
    new(params, account).matching_count
  rescue StandardError => e
    Rails.logger.error("[Captain][ConversationFilterMatcher] Error counting matching conversations: #{e.message}")
    0
  end

  # Normalizes stored filter conditions to the format FilterService expects:
  # - Values stored as [{id: x, name: y}] are reduced to plain [x] values.
  # - The last condition's query_operator is cleared to avoid trailing AND/OR in SQL.
  def self.normalize(filters)
    conditions = filters.map do |condition|
      h = condition.with_indifferent_access
      values = h[:values]
      h[:values] = Array.wrap(values).map { |v| v.is_a?(Hash) ? v['id'] || v[:id] : v }.compact
      h
    end
    conditions.last[:query_operator] = nil if conditions.any?
    conditions
  end

  def matches?(conversation)
    validate_query_operator
    result = query_builder(@filters['conversations'])
    result.where(id: conversation.id).exists?
  end

  def matching_ids
    validate_query_operator
    query_builder(@filters['conversations']).pluck(:id)
  end

  def matching_count
    validate_query_operator
    query_builder(@filters['conversations']).count
  end

  private

  def base_relation
    @account.conversations
  end
end
