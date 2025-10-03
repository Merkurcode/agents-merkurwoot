json.id pipeline_status.id
json.name pipeline_status.name
json.account_id pipeline_status.account_id

# json.conversations do
#   json.array! pipeline_status.conversations do |conversation|
#     json.account_id conversation.account_id
#     json.uuid conversation.uuid
#     json.additional_attributes conversation.additional_attributes
#     json.agent_last_seen_at conversation.agent_last_seen_at.to_i
#     json.assignee_last_seen_at conversation.assignee_last_seen_at.to_i
#     json.can_reply conversation.can_reply?
#     json.contact_last_seen_at conversation.contact_last_seen_at.to_i
#     json.custom_attributes conversation.custom_attributes
#     json.inbox_id conversation.inbox_id
#     json.labels conversation.cached_label_list_array
#     json.muted conversation.muted?
#     json.snoozed_until conversation.snoozed_until
#     json.status conversation.status
#     json.created_at conversation.created_at.to_i
#     json.updated_at conversation.updated_at.to_f
#     json.timestamp conversation.last_activity_at.to_i
#     json.first_reply_created_at conversation.first_reply_created_at.to_i
#     json.unread_count conversation.unread_incoming_messages.count
#     json.last_activity_at conversation.last_activity_at.to_i
#     json.priority conversation.priority
#     json.waiting_since conversation.waiting_since.to_i.to_i
#     json.sla_policy_id conversation.sla_policy_id
#   end
# end
