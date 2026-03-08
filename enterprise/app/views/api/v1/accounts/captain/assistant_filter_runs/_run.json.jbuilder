json.id run.id
json.status run.status
json.scheduled_at run.scheduled_at
json.message run.message
json.conversations_total run.conversations_total
json.conversations_processed run.conversations_processed
json.created_at run.created_at
json.updated_at run.updated_at

json.assistant_filter do
  json.id run.assistant_filter.id
  json.name run.assistant_filter.name
  json.captain_assistant_id run.assistant_filter.captain_assistant_id
  json.captain_assistant_name run.assistant_filter.captain_assistant.name
end

if run.triggered_by
  json.triggered_by do
    json.id run.triggered_by.id
    json.name run.triggered_by.name
  end
end
