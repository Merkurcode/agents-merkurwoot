json.payload do
  json.array! @filters do |filter|
    json.partial! 'api/v1/accounts/captain/assistant_filters/filter', filter: filter
  end
end

json.meta do
  json.total_count @filters.count
  json.page 1
end
