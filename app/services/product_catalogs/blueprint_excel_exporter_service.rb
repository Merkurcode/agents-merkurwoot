class ProductCatalogs::BlueprintExcelExporterService
  require 'write_xlsx'

  BLUEPRINT_MARKER_KEYS = %w[
    buyer_persona manejo_de_objeciones perfil_producto flujo_de_calificacion
    atributos_y_beneficios _blueprint_updated_at
  ].freeze

  def initialize(products)
    @products = products
  end

  def export
    products_with_blueprint = @products.select { |p| blueprint?(p) }

    io       = StringIO.new
    workbook = WriteXLSX.new(io)

    header_fmt = workbook.add_format(bold: 1, bg_color: '#4472C4', color: 'white', border: 1)
    id_fmt     = workbook.add_format(bold: 1, bg_color: '#C00000', color: 'white', border: 1)
    data_fmt   = workbook.add_format(text_wrap: 1, border: 1, valign: 'top')

    worksheet = workbook.add_worksheet('Perfiles de IA')
    worksheet.freeze_panes(1, 2)

    write_headers(worksheet, header_fmt, id_fmt)

    products_with_blueprint.each_with_index do |product, row_idx|
      write_product_row(worksheet, product, row_idx + 1, data_fmt)
    end

    apply_column_widths(worksheet)
    workbook.close
    io.string
  end

  private

  def blueprint?(product)
    meta = product.metadata || {}
    BLUEPRINT_MARKER_KEYS.any? { |k| meta.key?(k) }
  end

  def write_headers(worksheet, header_fmt, id_fmt)
    headers = ProductCatalogs::BlueprintExcelTemplateService::COLUMN_HEADERS
    headers.each_with_index do |header, col|
      fmt = col.zero? ? id_fmt : header_fmt
      worksheet.write(0, col, header, fmt)
    end
  end

  def write_product_row(worksheet, product, row, fmt)
    meta   = product.metadata || {}
    values = build_row_values(product, meta)
    append_attribute_pairs(values, meta['atributos_y_beneficios'] || [])

    flujo = meta['flujo_de_calificacion'] || {}
    objs  = meta['manejo_de_objeciones']  || {}
    values.concat([
      flujo['fase_a'], flujo['fase_b'], flujo['fase_c'], flujo['fase_d'],
      objs['es_caro'], objs['lo_pienso'], objs['competencia'],
      format_promotions(meta['promociones']),
      meta['notas']
    ])

    values.each_with_index do |val, col|
      next if val.nil? || val.to_s.empty?

      worksheet.write_string(row, col, val.to_s, fmt)
    end
  end

  def build_row_values(product, meta)
    perfil = meta['perfil_producto'] || {}
    buyer  = meta['buyer_persona']   || {}

    [
      product.product_id,
      product.productName,
      product.industry,
      perfil['usp'],
      perfil['modelo_de_precios'],
      perfil['unidad_de_valor'],
      buyer['segmento'],
      buyer['pain_point'],
      buyer['gain']
    ]
  end

  def append_attribute_pairs(values, atribs)
    5.times do |i|
      pair = atribs[i] || {}
      values << pair['atributo']
      values << pair['beneficio']
    end
  end

  def format_promotions(promos)
    return nil if promos.nil?

    promos.is_a?(Array) ? promos.join(';') : promos.to_s
  end

  def apply_column_widths(worksheet)
    worksheet.set_column(0, 0, 20)
    worksheet.set_column(1, 1, 32)
    worksheet.set_column(2, 2, 30)
    worksheet.set_column(3, 3, 55)
    worksheet.set_column(4, 4, 45)
    worksheet.set_column(5, 5, 28)
    worksheet.set_column(6, 8, 55)
    worksheet.set_column(9, 18, 35)
    worksheet.set_column(19, 22, 65)
    worksheet.set_column(23, 25, 65)
    worksheet.set_column(26, 26, 65)
    worksheet.set_column(27, 27, 50)
  end
end
