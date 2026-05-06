class Api::V1::Accounts::ProductBlueprintsController < Api::V1::Accounts::BaseController
  before_action :set_blueprint, only: [:show]
  before_action :check_authorization
  before_action :check_rate_limit, only: [:yaml_upload]

  MAX_YAML_FILE_SIZE = 5.megabytes
  ALLOWED_YAML_EXTENSIONS = %w[.yaml .yml].freeze
  ALLOWED_YAML_CONTENT_TYPES = %w[application/x-yaml application/yaml text/yaml text/x-yaml text/plain application/octet-stream].freeze
  RATE_LIMIT_SUFFIX = 'BLUEPRINT_YAML'.freeze

  def index
    @current_page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 50).to_i

    @blueprints = filtered_blueprints.order(name: :asc).page(@current_page).per(per_page)
    @total_count = @blueprints.total_count
    @total_pages = (@total_count.to_f / per_page).ceil
    @product_catalog_ids = product_catalog_id_lookup(@blueprints.map(&:name))
  end

  def show
    @product_catalog_ids = product_catalog_id_lookup([@blueprint.name])
  end

  def by_name
    name = params[:name].to_s.strip
    if name.blank?
      render json: { error: 'Missing required parameter: name' }, status: :unprocessable_entity
      return
    end

    @blueprint = Current.account.product_blueprints.find_by(name: name)
    if @blueprint.nil?
      render json: { error: "Blueprint not found for name '#{name}'" }, status: :not_found
      return
    end

    @product_catalog_ids = product_catalog_id_lookup([@blueprint.name])
    render :show
  end

  def yaml_upload
    uploaded_file = params[:file]
    return render json: { error: 'No file provided' }, status: :unprocessable_entity if uploaded_file.blank?

    unless ProductCatalogs::RateLimiterService.acquire_validation_lock(Current.account.id, RATE_LIMIT_SUFFIX)
      return render json: { error: 'Another upload is being validated. Please wait a moment and try again.' },
                    status: :too_many_requests
    end

    process_yaml_upload(uploaded_file)
  ensure
    ProductCatalogs::RateLimiterService.release_validation_lock(Current.account.id, RATE_LIMIT_SUFFIX)
  end

  def yaml_template
    template_path = Rails.root.join('lib/templates/product_blueprint_template.yaml')
    send_file template_path,
              filename: 'product_blueprint_template.yaml',
              type: 'application/x-yaml',
              disposition: 'attachment'
  end

  private

  def set_blueprint
    @blueprint = Current.account.product_blueprints.find(params[:id])
  end

  def filtered_blueprints
    scope = Current.account.product_blueprints
    scope = scope.by_exact_name(params[:name]) if params[:name].present?
    scope = scope.where(id: params[:id]) if params[:id].present?
    scope
  end

  def product_catalog_id_lookup(names)
    return {} if names.blank?

    Current.account.product_catalogs
           .where(productName: names)
           .pluck(:productName, :id)
           .to_h
  end

  def process_yaml_upload(uploaded_file)
    validation_error = validate_yaml_file(uploaded_file)
    return render json: { error: validation_error }, status: :unprocessable_entity if validation_error

    active_request = active_yaml_blueprint_request
    if active_request
      return render json: {
        error: 'A YAML blueprint upload is already being processed. Please wait for it to complete.',
        active_request_id: active_request.id
      }, status: :unprocessable_entity
    end

    dismiss_previous_yaml_blueprint_requests

    temp_file = save_uploaded_file(uploaded_file)
    queue_yaml_blueprint_job(uploaded_file, temp_file)
  rescue StandardError
    FileUtils.rm_f(temp_file) if temp_file && File.exist?(temp_file)
    raise
  end

  def queue_yaml_blueprint_job(uploaded_file, temp_file)
    @bulk_request = Current.account.bulk_processing_requests.create!(
      user: current_user,
      entity_type: 'ProductBlueprint',
      import_format: 'yaml_blueprint',
      file_name: uploaded_file.original_filename,
      status: 'PENDING'
    )

    job = ProductCatalogs::ProcessBulkUploadJob.perform_later(@bulk_request.id, temp_file)
    @bulk_request.update!(job_id: job.provider_job_id)

    render json: { bulk_request_id: @bulk_request.id }, status: :accepted
  end

  def validate_yaml_file(uploaded_file)
    return 'File too large. Maximum size is 5MB.' if uploaded_file.size > MAX_YAML_FILE_SIZE

    extension = File.extname(uploaded_file.original_filename).downcase
    return 'Invalid file type. Only YAML files (.yaml, .yml) are allowed.' unless ALLOWED_YAML_EXTENSIONS.include?(extension)

    unless ALLOWED_YAML_CONTENT_TYPES.include?(uploaded_file.content_type.to_s.split(';').first.to_s.strip)
      return 'Invalid content type. Please upload a plain text YAML file.'
    end

    return 'Filename too long. Maximum 100 characters allowed.' if uploaded_file.original_filename.length > 100

    nil
  end

  def active_yaml_blueprint_request
    Current.account.bulk_processing_requests
           .where(entity_type: 'ProductBlueprint', import_format: 'yaml_blueprint')
           .where(status: %w[PENDING PROCESSING])
           .first
  end

  def dismiss_previous_yaml_blueprint_requests
    Current.account.bulk_processing_requests
           .where(entity_type: 'ProductBlueprint', import_format: 'yaml_blueprint')
           .where(dismissed_at: nil)
           .update_all(dismissed_at: Time.current)
  end

  def save_uploaded_file(uploaded_file)
    temp_dir = Rails.root.join('tmp/uploads')
    FileUtils.mkdir_p(temp_dir)

    safe_filename = File.basename(uploaded_file.original_filename)
    temp_file_path = temp_dir.join("#{SecureRandom.uuid}_#{safe_filename}")

    File.binwrite(temp_file_path, uploaded_file.read)

    temp_file_path.to_s
  end

  def check_rate_limit
    return if ProductCatalogs::RateLimiterService.acquire_lock(Current.account.id, 'BLUEPRINT', RATE_LIMIT_SUFFIX)

    lock_info = ProductCatalogs::RateLimiterService.lock_info(Current.account.id)
    remaining = lock_info&.dig(:remaining_seconds) || ProductCatalogs::RateLimiterService::RATE_LIMIT_SECONDS

    render json: {
      error: "Rate limit exceeded. Please wait #{remaining} seconds before trying again.",
      retry_after: remaining,
      current_operation: lock_info&.dig(:operation_type)
    }, status: :too_many_requests
  end
end
