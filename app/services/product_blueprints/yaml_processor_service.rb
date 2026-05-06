class ProductBlueprints::YamlProcessorService
  EXTRA_SECTION_KEYS = %w[atributos_y_beneficios flujo_calificacion manejo_de_objeciones].freeze
  PROGRESS_UPDATE_THROTTLE_SECONDS = 2

  def initialize(file_path:, account:, user:, bulk_request:)
    @file_path = file_path
    @account = account
    @user = user
    @bulk_request = bulk_request
    @errors = []
  end

  def process
    Rails.logger.info('YamlBlueprintProcessor: Starting YAML blueprint processing...')

    productos = Array(parse_yaml&.dig('productos'))
    return { success: false, error: 'YAML has no "productos" entries', errors: [] } if productos.empty?

    @bulk_request.update!(total_records: productos.size, progress: 0.0)
    preload_lookup_caches
    iterate_productos(productos)

    @bulk_request.update!(progress: 100.0, updated_at: Time.current)
    Rails.logger.info("YamlBlueprintProcessor: Completed processing #{productos.size} entries")

    { success: true, total_rows: productos.size, errors: @errors }
  rescue Psych::SyntaxError => e
    handle_processing_error("Invalid YAML syntax: #{e.message}", e)
  rescue Psych::DisallowedClass => e
    handle_processing_error("YAML contains disallowed content: #{e.message}", e)
  rescue Errno::ENOENT => e
    handle_processing_error('File not found. Please try uploading again.', e)
  rescue StandardError => e
    handle_processing_error("YAML processing failed: #{e.message}", e)
  end

  private

  def parse_yaml
    YAML.safe_load(File.read(@file_path), aliases: true, permitted_classes: [Date, Time])
  end

  def preload_lookup_caches
    @existing_product_names = @account.product_catalogs.pluck(:productName).to_set
    @existing_blueprints = @account.product_blueprints.index_by(&:name)
  end

  def iterate_productos(productos)
    last_progress_update = Time.current
    productos.each_with_index do |producto, index|
      process_one(producto, index + 1)

      if Time.current - last_progress_update > PROGRESS_UPDATE_THROTTLE_SECONDS
        update_progress(index + 1, productos.size)
        last_progress_update = Time.current
      end
    end
  end

  def process_one(producto, row_index)
    name = validate_entry(producto, row_index)
    return unless name

    blueprint = @existing_blueprints[name] || @account.product_blueprints.new(name: name, user: @user)
    blueprint.assign_attributes(blueprint_attributes(producto))
    blueprint.save!

    @existing_blueprints[name] = blueprint
    @bulk_request.increment!(:processed_records)
  rescue ActiveRecord::RecordInvalid => e
    record_failure(row_index, name, 'validation_error', e.record.errors.full_messages.join(', '))
  rescue StandardError => e
    Rails.logger.error("YamlBlueprintProcessor: Unexpected error on row #{row_index}: #{e.message}")
    record_failure(row_index, name, 'unexpected_error', e.message)
  end

  def validate_entry(producto, row_index)
    unless producto.is_a?(Hash)
      record_failure(row_index, nil, 'invalid_entry', 'Entrada inválida (se esperaba un hash)')
      return nil
    end

    name = producto['name'].to_s.strip.presence
    unless name
      record_failure(row_index, nil, 'missing_name', 'Producto sin nombre')
      return nil
    end

    unless @existing_product_names.include?(name)
      record_failure(row_index, name, 'product_not_found',
                     "No existe un producto con el nombre exacto '#{name}' en el catálogo")
      return nil
    end

    name
  end

  def blueprint_attributes(producto)
    {
      external_id: producto['id'].presence,
      resumen_agente: producto['resumen_agente'],
      perfil_producto: producto['perfil_producto'],
      buyer_persona: producto['buyer_persona'],
      extra_sections: extract_extra_sections(producto),
      bulk_processing_request: @bulk_request,
      last_updated_by: @user
    }
  end

  def extract_extra_sections(producto)
    extras = EXTRA_SECTION_KEYS.each_with_object({}) do |key, hash|
      hash[key] = producto[key] if producto.key?(key)
    end
    extras.empty? ? nil : extras
  end

  def record_failure(row_index, name, reason, message)
    @errors << { row: row_index, name: name, reason: reason, error: message }
    @bulk_request.increment!(:failed_records)
  end

  def update_progress(processed, total)
    progress = (processed.to_f / total * 100).round(2)
    @bulk_request.update!(progress: progress, updated_at: Time.current)
  end

  def handle_processing_error(error_msg, original_error)
    Rails.logger.error("YAML blueprint processing error: #{error_msg}")
    Rails.logger.error(original_error.backtrace.join("\n")) if original_error.backtrace
    { success: false, error: error_msg, errors: @errors }
  end
end
