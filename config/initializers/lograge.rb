if ActiveModel::Type::Boolean.new.cast(ENV.fetch('LOGRAGE_ENABLED', false)).present?
  require 'lograge'

  Rails.application.configure do
    config.lograge.enabled = true
    config.lograge.formatter = Lograge::Formatters::Json.new
    config.lograge.custom_payload do |controller|
      # We only need user_id for API requests
      # might error out for other controller - ref: https://github.com/chatwoot/chatwoot/issues/6922
      user_id = controller&.try(:current_user)&.id if controller.is_a?(Api::BaseController) && controller&.try(:current_user).is_a?(User)
      {
        host: controller.request.host,
        remote_ip: controller.request.remote_ip,
        user_id: user_id
      }
    end

    config.lograge.custom_options = lambda do |event|
      param_exceptions = %w[controller action format id]
      {
        params: event.payload[:params]&.except(*param_exceptions)
      }
    end

    config.lograge.ignore_custom = lambda do |event|
      # ignore update_presence  events in log
      return true if event.payload[:channel_class] == 'RoomChannel'
    end
  end
end

if ENV['DATADOG_LOGGING']
  require 'lograge'

  Rails.application.configure do
    config.lograge.enabled = true
    config.lograge.formatter = Lograge::Formatters::Json.new

    config.lograge.custom_options = lambda do |event|
      status = event.payload[:status].to_i
      level = if event.payload[:exception].present? || status >= 500
                "ERROR"
              elsif status >= 400
                "WARN"
              else
                "INFO"
              end

      {
        timestamp: Time.current.iso8601,
        service: "crm_rails",
        ddsource: "rails",
        level: level,
        message: "#{event.payload[:method]} #{event.payload[:path]}",
        status: status,
        duration: event.duration,
        request_id: event.payload[:request_id],
        user_id: event.payload[:user_id],
        env: Rails.env
      }
    end

    config.lograge.ignore_custom = lambda do |event|
      return true if event.payload[:channel_class] == 'RoomChannel'
      return true if event.payload[:controller] == 'ApplicationCable::Connection'
    end

    config.logger = ActiveSupport::Logger.new($stdout)
    config.log_level = :info
  end
end
