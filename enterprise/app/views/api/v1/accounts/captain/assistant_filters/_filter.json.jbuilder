json.id filter.id
json.name filter.name
json.filters filter.filters
json.active filter.active
json.captain_assistant_id filter.captain_assistant_id
json.captain_assistant_name filter.captain_assistant.name
json.matching_conversations_count Captain::ConversationFilterMatcher.matching_count(filters: filter.filters, account: filter.account)
json.created_at filter.created_at
json.updated_at filter.updated_at
