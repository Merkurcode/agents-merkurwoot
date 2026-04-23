json.id @task.id
json.title @task.title
json.description @task.description
json.status @task.status
json.action_type @task.action_type
json.scheduled_at @task.scheduled_at
json.assignee_id @task.assignee_id
json.ai_agent_id @task.ai_agent_id
json.execution_config @task.execution_config
json.entity_type @task.entity_type
json.entity_id @task.entity_id
json.creator_id @task.creator_id
json.created_at @task.created_at
json.updated_at @task.updated_at

if @task.creator.present?
  json.creator do
    json.id @task.creator.id
    json.name @task.creator.name
    json.avatar_url @task.creator.avatar_url
  end
else
  json.creator nil
end

if @task.assignee.present?
  json.assignee do
    json.id @task.assignee.id
    json.name @task.assignee.name
    json.avatar_url @task.assignee.avatar_url
  end
else
  json.assignee nil
end

if @task.ai_agent.present?
  json.ai_agent do
    json.id @task.ai_agent.id
    json.name @task.ai_agent.name
  end
else
  json.ai_agent nil
end
