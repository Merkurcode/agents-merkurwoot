class ProductCatalogs::BlueprintExcelProcessorService
  # Column mapping: col index → { field:, type:, sku: (optional, marks SKU fields) }
  # Layout: A(0)=ID, B(1)=Nombre, C(2)=Categoría, D(3)=USP, E(4)=Modelo Precios, F(5)=Unidad Valor,
  #         G-I(6-8)=Buyer Persona, J-S(9-18)=5 Atributo/Beneficio pairs,
  #         T-W(19-22)=Flujo Calificación A-D, X-Z(23-25)=3 Objeciones, AA-AB(26-27)=Extras
  BLUEPRINT_COLUMN_MAPPING = {
    0  => { field: 'product_id',                          type: :string },
    1  => { field: 'productName',                         type: :string, sku: true },
    2  => { field: 'industry',                            type: :string, sku: true },
    3  => { field: 'perfil_producto.usp',                 type: :string },
    4  => { field: 'perfil_producto.modelo_de_precios',   type: :string },
    5  => { field: 'perfil_producto.unidad_de_valor',     type: :string },
    6  => { field: 'buyer_persona.segmento',              type: :string },
    7  => { field: 'buyer_persona.pain_point',            type: :string },
    8  => { field: 'buyer_persona.gain',                  type: :string },
    19 => { field: 'flujo_de_calificacion.fase_a',        type: :string },
    20 => { field: 'flujo_de_calificacion.fase_b',        type: :string },
    21 => { field: 'flujo_de_calificacion.fase_c',        type: :string },
    22 => { field: 'flujo_de_calificacion.fase_d',        type: :string },
    23 => { field: 'manejo_de_objeciones.es_caro',        type: :string },
    24 => { field: 'manejo_de_objeciones.lo_pienso',      type: :string },
    25 => { field: 'manejo_de_objeciones.competencia',    type: :string },
    26 => { field: 'promociones',                         type: :semicolon_array },
    27 => { field: 'notas',                               type: :string }
  }.freeze

  # Attribute/benefit pairs: cols J(9)–S(18), 5 pairs
  ATTRIBUTE_PAIR_START_COL = 9
  MAX_ATTRIBUTE_PAIRS      = 5

  # Section keys (nested hashes): replaced atomically if blueprint has any value in the section
  BLUEPRINT_SECTION_KEYS = %w[
    perfil_producto buyer_persona atributos_y_beneficios flujo_de_calificacion manejo_de_objeciones
  ].freeze

  # Scalar/array top-level blueprint keys: updated individually if value present
  SCALAR_BLUEPRINT_KEYS = %w[notas promociones].freeze

  # Required for new products (NOT NULL in DB); existing products use COALESCE
  NEW_PRODUCT_REQUIRED_FIELDS = %w[productName].freeze

  BATCH_SIZE = 50_000

  def initialize(file_path:, account:, user:, bulk_request:)
    @file_path    = file_path
    @account      = account
    @user         = user
    @bulk_request = bulk_request
    @errors       = []
  end

  def process
    Rails.logger.info('BlueprintProcessor: Starting blueprint Excel processing...')

    conn = ActiveRecord::Base.connection.raw_connection
    @bulk_request.update!(total_records: 0)

    preload_existing_metadata

    total_rows = process_with_copy_streaming(conn)

    Rails.logger.info("BlueprintProcessor: Completed processing #{total_rows} rows")

    { success: @errors.empty?, total_rows: total_rows, errors: @errors }
  rescue Zip::Error => e
    handle_processing_error("Invalid Excel file: #{e.message}", e)
  rescue Roo::Error => e
    handle_processing_error("Invalid Excel file: #{e.message}", e)
  rescue Errno::ENOENT => e
    handle_processing_error('File not found. Please try uploading again.', e)
  rescue PG::Error => e
    handle_processing_error("Database error: #{extract_pg_error_message(e)}", e)
  rescue StandardError => e
    handle_processing_error("Blueprint processing failed: #{e.message}", e)
  end

  private

  def preload_existing_metadata
    @existing_metadata_map = @account.product_catalogs
                                     .pluck(:product_id, :metadata)
                                     .transform_values { |meta| (meta || {}) }
    Rails.logger.info("BlueprintProcessor: Preloaded metadata for #{@existing_metadata_map.size} existing products")
  end

  def process_with_copy_streaming(conn)
    xlsx = Roo::Excelx.new(@file_path)
    @roo_temp_dir = xlsx.instance_variable_get(:@tmpdir)

    conn.exec('SET synchronous_commit TO OFF')
    conn.exec("SET maintenance_work_mem TO '256MB'")
    conn.exec("SET work_mem TO '64MB'")

    row_index       = 0
    buffer          = []
    last_update     = Time.current

    xlsx.each_row_streaming(pad_cells: true) do |row|
      if row_index.zero?
        row_index += 1
        next
      end

      if (row_index % 10_000).zero?
        @bulk_request.reload
        break unless %w[PENDING PROCESSING].include?(@bulk_request.status.upcase)
      end

      row_data = extract_row_data(row)
      error    = validate_row(row_data, row_index)

      if error
        @errors << { row: row_index, product_id: row_data['product_id'], error: error }
        @bulk_request.increment!(:failed_records)
        row_index += 1
        next
      end

      buffer << prepare_row_for_copy(row_data)
      row_index += 1

      if buffer.size >= BATCH_SIZE
        flush_batch(conn, buffer)
        buffer.clear
        @bulk_request.update!(total_records: row_index - 1, progress: 50.0, updated_at: Time.current)
        last_update = Time.current
      elsif Time.current - last_update > 2.seconds
        @bulk_request.update!(
          total_records: row_index - 1,
          progress: [((row_index - 1) * 0.5).round(2), 49.0].min,
          updated_at: Time.current
        )
        last_update = Time.current
      end
    end

    flush_batch(conn, buffer) if buffer.any?

    total = row_index - 1
    @bulk_request.update!(total_records: total, progress: 100.0, updated_at: Time.current)
    Rails.logger.info("BlueprintProcessor: Phase complete. #{total} rows, 100%")
    total
  ensure
    cleanup_roo_temp_dir
  end

  def extract_row_data(row)
    data = {}

    BLUEPRINT_COLUMN_MAPPING.each do |col_index, mapping|
      cell      = row[col_index]
      raw_value = cell.respond_to?(:value) ? cell.value : cell
      data[mapping[:field]] = coerce_value(raw_value, mapping[:type])
    end

    pairs = extract_attribute_pairs(row)
    data['atributos_y_beneficios'] = pairs if pairs.any?

    data['product_id'] = data['product_id'].presence || SecureRandom.uuid
    data
  end

  def extract_attribute_pairs(row)
    pairs = []
    MAX_ATTRIBUTE_PAIRS.times do |i|
      atributo_col = ATTRIBUTE_PAIR_START_COL + (i * 2)
      beneficio_col = atributo_col + 1

      atributo = raw_cell_string(row[atributo_col])
      beneficio = raw_cell_string(row[beneficio_col])

      pairs << { 'atributo' => atributo, 'beneficio' => beneficio } if atributo.present? || beneficio.present?
    end
    pairs
  end

  def raw_cell_string(cell)
    value = cell.respond_to?(:value) ? cell.value : cell
    value.to_s.strip.presence
  end

  def coerce_value(raw, type)
    str = raw.is_a?(String) ? raw.strip : raw.to_s.strip
    return nil if str.empty? && !raw.is_a?(Numeric) && !raw.is_a?(TrueClass) && !raw.is_a?(FalseClass)

    case type
    when :string         then str.empty? ? nil : str
    when :decimal        then if str.empty?
                                nil
                              else
                                str.gsub(/[^0-9.]/, '').to_d.then { |v| v.zero? && str.exclude?('0') ? nil : v }
                              end
    when :integer        then str.empty? ? nil : str.to_i
    when :boolean        then normalize_boolean(raw)
    when :semicolon_array
      return nil if str.empty?

      parts = str.split(';').map(&:strip).reject(&:empty?)
      parts.any? ? parts : nil
    end
  end

  def normalize_boolean(value)
    normalized = value.to_s.strip.downcase
    %w[sí si true 1 yes].include?(normalized)
  end

  def validate_row(row_data, _row_index)
    product_id = row_data['product_id']
    return nil if @existing_metadata_map.key?(product_id)

    missing = NEW_PRODUCT_REQUIRED_FIELDS.select { |f| row_data[f].blank? }
    return nil if missing.empty?

    "Producto nuevo requiere los campos: #{missing.join(', ')}"
  end

  def build_blueprint_sections(row_data)
    blueprint = {}

    BLUEPRINT_COLUMN_MAPPING.each_value do |mapping|
      next if mapping[:sku]

      field = mapping[:field]
      value = row_data[field]
      next if value.nil?

      parts = field.split('.')
      if parts.length == 2
        blueprint[parts[0]] ||= {}
        blueprint[parts[0]][parts[1]] = value
      else
        blueprint[field] = value
      end
    end

    blueprint['atributos_y_beneficios'] = row_data['atributos_y_beneficios'] if row_data['atributos_y_beneficios'].present?

    blueprint
  end

  def merge_metadata(product_id, blueprint_sections)
    existing = @existing_metadata_map[product_id] || {}
    merged   = existing.dup

    # Section-level replace: if any key in a section has a value, replace the whole section
    BLUEPRINT_SECTION_KEYS.each do |key|
      new_section = blueprint_sections[key]
      next if new_section.blank?

      replaced = if new_section.is_a?(Hash)
                   compact = new_section.compact
                   compact.any? ? compact : nil
                 else
                   new_section
                 end

      merged[key] = replaced if replaced.present?
    end

    # Scalar keys: update if value is present
    SCALAR_BLUEPRINT_KEYS.each do |key|
      merged[key] = blueprint_sections[key] if blueprint_sections.key?(key) && blueprint_sections[key].present?
    end

    merged['_blueprint_updated_at'] = Time.current.iso8601
    merged
  end

  def prepare_row_for_copy(row_data)
    product_id        = row_data['product_id']
    blueprint_data    = build_blueprint_sections(row_data)
    merged_metadata   = merge_metadata(product_id, blueprint_data)

    [
      @account.id,
      product_id,
      row_data['industry'],
      row_data['productName'],
      nil,   # type — not provided by blueprint template; COALESCE preserves existing value
      nil,   # subcategory — idem
      nil,   # listPrice — idem
      merged_metadata.to_json,
      @bulk_request.id,
      @user.id,
      @user.id,
      Time.current,
      Time.current
    ]
  end

  def flush_batch(conn, rows)
    return if rows.empty?

    copy_batch_to_db(conn, rows)
    @bulk_request.increment!(:processed_records, rows.size)
  end

  def copy_batch_to_db(conn, rows)
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

      # Preserve existing SKU fields for existing products via CASE WHEN
      update_sku_fields = %w[productName type industry subcategory listPrice].map do |col|
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

  def cleanup_roo_temp_dir
    return unless defined?(@roo_temp_dir) && @roo_temp_dir.present?

    if Dir.exist?(@roo_temp_dir)
      FileUtils.rm_rf(@roo_temp_dir)
      Rails.logger.info("BlueprintProcessor: Cleaned up Roo temp dir: #{@roo_temp_dir}")
    end
  rescue StandardError => e
    Rails.logger.warn("BlueprintProcessor: Failed to cleanup Roo temp dir: #{e.message}")
  end

  def handle_processing_error(error_msg, original_error)
    Rails.logger.error("Blueprint processing error: #{error_msg}")
    Rails.logger.error(original_error.backtrace.join("\n"))
    { success: false, error: error_msg, errors: @errors }
  end

  def extract_pg_error_message(pg_error)
    msg = pg_error.message
    if msg.include?('null value in column')
      match  = msg.match(/null value in column "([^"]+)"/)
      column = match ? match[1] : 'unknown'
      "Campo requerido '#{column}' está vacío"
    else
      msg.split("\n").first
    end
  end
end
