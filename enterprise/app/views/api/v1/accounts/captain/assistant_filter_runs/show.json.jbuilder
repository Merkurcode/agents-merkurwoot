json.partial! 'api/v1/accounts/captain/assistant_filter_runs/run', run: @run

json.stats do
  run_convs = @run.run_conversations
  json.total run_convs.count
  json.pending run_convs.pending.count
  json.success run_convs.success.count
  json.failed run_convs.failed.count
end

page = (params[:page] || 1).to_i
paginated = @run.run_conversations.includes(:conversation).order(:created_at).page(page).per(25)

json.conversations do
  json.array! paginated do |rc|
    json.id rc.id
    json.status rc.status
    json.error_message rc.error_message
    json.processed_at rc.processed_at
    json.conversation do
      json.id rc.conversation.id
      json.display_id rc.conversation.display_id
      json.status rc.conversation.status
      json.inbox_id rc.conversation.inbox_id
    end
  end
end

json.conversations_meta do
  json.total_count paginated.total_count
  json.page paginated.current_page
end
