class ProductCatalogs::BlueprintYamlProcessorService
  BLUEPRINT_SECTION_KEYS = %w[
    perfil_producto buyer_persona atributos_y_beneficios flujo_de_calificacion manejo_de_objeciones
  ].freeze

  SCALAR_BLUEPRINT_KEYS = %w[notas promociones].freeze

  # Extra YAML-specific keys stored as-is in metadata
  YAML_EXTRA_KEYS = %w[
    precios recommendation_rules name_match is_base_plan tipo is_cloud
    max_dispositivos multi_sucursal descripcion_tipo
  ].freeze

  BATCH_SIZE = 500

  def initialize(file_path:, account:, user:, bulk_request:)
    @file_path    = file_path
    @account      = account
    @user         = user
    @bulk_request = bulk_request
    @errors       = []
  end

  def process
    Rails.logger.info('BlueprintYamlProcessor: Starting YAML blueprint processing...')

    raw       = YAML.safe_load(File.read(@file_path))
    productos = Array(raw&.dig('productos'))

    if productos.empty?
      return { success: false, error: 'YAML inválido: se esperaba la clave "productos" con al menos un producto.', errors: [] }
    end

    @bulk_request.update!(total_records: productos.size)
    preload_existing_metadata

    conn = ActiveRecord::Base.connection.raw_connection
    conn.exec('SET synchronous_commit TO OFF')

    buffer    = []
    processed = 0

    productos.each_with_index do |data, idx|
      error = validate_product(data, idx + 1)
      if error
        @errors << { row: idx + 1, product_id: data&.dig('id'), error: error }
        @bulk_request.increment!(:failed_records)
        next
      end

      buffer << build_row(data)
      processed = idx + 1

      if buffer.size >= BATCH_SIZE || processed == productos.size
        flush_batch(conn, buffer)
        buffer.clear
        progress = (processed.to_f / productos.size * 100).round(2)
        @bulk_request.update!(processed_records: processed - @bulk_request.failed_records, progress: progress)
      end
    end

    @bulk_request.update!(progress: 100.0)
    Rails.logger.info("BlueprintYamlProcessor: Completed #{productos.size} products")

    { success: @errors.empty?, total_rows: productos.size, errors: @errors }
  rescue Psych::SyntaxError => e
    handle_error("YAML inválido: #{e.message}")
  rescue Errno::ENOENT
    handle_error('Archivo no encontrado. Vuelve a intentar la carga.')
  rescue PG::Error => e
    handle_error("Error de base de datos: #{e.message.split("\n").first}")
  rescue StandardError => e
    handle_error("Error procesando blueprint: #{e.message}")
  end

  private

  def preload_existing_metadata
    @existing_metadata_map = @account.product_catalogs
                                     .pluck(:product_id, :metadata)
                                     .each_with_object({}) { |(id, meta), h| h[id] = meta || {} }
    Rails.logger.info("BlueprintYamlProcessor: Preloaded #{@existing_metadata_map.size} existing products")
  end

  def validate_product(data, _row)
    return 'Falta el campo "id"' if data.blank? || data['id'].blank?
    return 'Falta el campo "nombre" para producto nuevo' if data['nombre'].blank? && !@existing_metadata_map.key?(data['id'].to_s)

    nil
  end

  def build_row(data)
    product_id = data['id'].to_s.strip
    merged     = merge_metadata(product_id, data)

    [
      @account.id,
      product_id,
      data['categoria'].presence,
      data['nombre'].presence,
      nil, nil, nil,
      merged.to_json,
      @bulk_request.id,
      @user.id,
      @user.id,
      Time.current,
      Time.current
    ]
  end

  def merge_metadata(product_id, data)
    merged = (@existing_metadata_map[product_id] || {}).dup

    BLUEPRINT_SECTION_KEYS.each do |key|
      new_val = data[key]
      next if new_val.blank?

      replaced = if new_val.is_a?(Hash)
                   compact = new_val.compact
                   compact.any? ? compact : nil
                 else
                   new_val
                 end
      merged[key] = replaced if replaced.present?
    end

    SCALAR_BLUEPRINT_KEYS.each do |key|
      merged[key] = data[key] if data.key?(key) && data[key].present?
    end

    YAML_EXTRA_KEYS.each do |key|
      merged[key] = data[key] if data.key?(key) && !data[key].nil?
    end

    merged['_blueprint_updated_at'] = Time.current.iso8601
    merged
  end

  def flush_batch(conn, rows)
    return if rows.empty?

    columns = %w[
      account_id product_id industry productName type subcategory
      listPrice metadata bulk_processing_request_id user_id last_updated_by_id
      created_at updated_at
    ]
    column_list = columns.map { |c| %("#{c}") }.join(', ')
    temp_table  = "temp_blueprints_#{SecureRandom.hex(8)}"

    begin
      conn.exec("CREATE TEMP TABLE #{temp_table} (LIKE product_catalogs INCLUDING DEFAULTS)")

      conn.copy_data("COPY #{temp_table} (#{column_list}) FROM STDIN WITH (FORMAT text)") do
        rows.each do |tuple|
          line = tuple.map do |v|
            v.nil? ? '\N' : v.to_s.gsub('\\', '\\\\').gsub("\t", '\\t').gsub("\n", '\\n').gsub("\r", '\\r')
          end.join("\t") + "\n"
          conn.put_copy_data(line)
        end
      end

      update_sku_fields = %w[productName industry].map do |col|
        %("#{col}" = CASE WHEN EXCLUDED."#{col}" IS NOT NULL THEN EXCLUDED."#{col}" ELSE product_catalogs."#{col}" END)
      end.join(', ')

      conn.exec(<<~SQL.squish)
        INSERT INTO product_catalogs (#{column_list})
        SELECT #{column_list} FROM #{temp_table}
        ON CONFLICT (account_id, product_id)
        DO UPDATE SET
          #{update_sku_fields},
          "metadata" = EXCLUDED."metadata",
          "bulk_processing_request_id" = EXCLUDED."bulk_processing_request_id",
          "last_updated_by_id" = EXCLUDED."last_updated_by_id",
          "updated_at" = EXCLUDED."updated_at"
      SQL
    ensure
      conn.exec("DROP TABLE IF EXISTS #{temp_table}")
    end
  end

  def handle_error(msg)
    Rails.logger.error("BlueprintYamlProcessor: #{msg}")
    { success: false, error: msg, errors: @errors }
  end
end
