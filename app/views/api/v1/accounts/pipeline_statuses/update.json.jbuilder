json.data do
  json.pipeline_status do
    json.partial! '/api/v1/models/pipeline_status', pipeline_status: @pipeline_status
  end
end
