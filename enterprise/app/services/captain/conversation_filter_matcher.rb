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

      params = { payload: assistant_filter.filters }
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
    params = { payload: filters }
    new(params, account).matching_ids
  rescue StandardError => e
    Rails.logger.error("[Captain][ConversationFilterMatcher] Error getting matching IDs: #{e.message}")
    []
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

  private

  def base_relation
    @account.conversations
  end
end
