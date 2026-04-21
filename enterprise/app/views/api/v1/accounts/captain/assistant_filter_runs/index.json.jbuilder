json.payload do
  json.array! @runs do |run|
    json.partial! 'api/v1/accounts/captain/assistant_filter_runs/run', run: run
  end
end

json.meta do
  json.total_count @runs.total_count
  json.page @runs.current_page
end
