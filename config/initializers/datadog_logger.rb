require 'net/http'
require 'uri'
require 'json'

# Formatter that intercepts every log entry, writes it to stdout,
# and also ships it to Datadog via HTTP intake.
#
# If the message is already JSON (e.g. from lograge), it is forwarded as-is.
# Plain text messages are wrapped in the standard Datadog JSON format.
class DatadogLogForwarder < Logger::Formatter
  def initialize
    @endpoint = URI(ENV.fetch('DATADOG_LOG_ENDPOINT'))
    @mutex    = Mutex.new
    @http     = nil
    super()
  end

  def call(severity, _datetime, _progname, message)
    message = message.to_s
    Thread.new { push_to_datadog(severity, message) }
    "#{message}\n"
  end

  private

  def push_to_datadog(severity, message)
    payload = begin
      # lograge already produces a complete Datadog JSON with all fields — send as-is
      JSON.parse(message)
      message
    rescue JSON::ParserError
      # plain text — wrap in standard Datadog format
      JSON.generate(
        timestamp: Time.now.utc.iso8601,
        service:   "crm_rails",
        ddsource:  "rails",
        level:     severity,
        message:   message,
        env:       Rails.env
      )
    end

    @mutex.synchronize { send_request(payload) }
  rescue StandardError => e
    $stderr.puts "[DatadogLogForwarder] Failed to send log: #{e.class} #{e.message}"
  end

  def send_request(payload, attempt: 0)
    req = Net::HTTP::Post.new(@endpoint.path)
    req['Content-Type'] = 'application/json'
    req.body = payload
    http.request(req)
  rescue IOError, Errno::ECONNRESET, Net::ReadTimeout
    @http = nil
    send_request(payload, attempt: attempt + 1) if attempt.zero?
  end

  def http
    @http ||= Net::HTTP.new(@endpoint.host, @endpoint.port).tap do |h|
      h.use_ssl      = @endpoint.scheme == 'https'
      h.verify_mode  = OpenSSL::SSL::VERIFY_NONE
      h.open_timeout = 3
      h.read_timeout = 5
      h.start
    end
  end
end

if ENV['DATADOG_LOGGING'] && ENV['DATADOG_LOG_ENDPOINT'].present?
  stdout_logger           = ActiveSupport::Logger.new($stdout)
  stdout_logger.formatter = DatadogLogForwarder.new
  Rails.logger            = ActiveSupport::BroadcastLogger.new(stdout_logger)
  Rails.logger.level      = Logger.const_get(ENV.fetch('LOG_LEVEL', 'info').upcase)
end
