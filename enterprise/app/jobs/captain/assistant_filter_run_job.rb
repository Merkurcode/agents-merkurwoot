class Captain::AssistantFilterRunJob < ApplicationJob
  queue_as :default
  retry_on StandardError, attempts: 1

  def perform(filter_run)
    Captain::AssistantFilterRunService.new(filter_run: filter_run).perform
  end
end
