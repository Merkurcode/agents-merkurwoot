class ProductCatalogs::BlueprintExcelTemplateService
  require 'write_xlsx'

  COLUMN_HEADERS = [
    'ID del Producto',                                  # A   0
    'Nombre del Producto/Servicio',                     # B   1
    'Categoría de Mercado',                             # C   2
    'Propuesta de Valor Única (USP)',                   # D   3
    'Modelo de Precios',                                # E   4
    'Unidad de Medida/Valor',                           # F   5
    '¿Para quién es? (Segmento)',                       # G   6
    'Dolor Principal (Pain Point)',                     # H   7
    'Deseo Aspiracional (Gain)',                        # I   8
    'Atributo 1', 'Beneficio 1',                       # J,K  9,10
    'Atributo 2', 'Beneficio 2',                       # L,M  11,12
    'Atributo 3', 'Beneficio 3',                       # N,O  13,14
    'Atributo 4', 'Beneficio 4',                       # P,Q  15,16
    'Atributo 5', 'Beneficio 5',                       # R,S  17,18
    'Fase A — Diagnóstico de Situación',               # T   19
    'Fase B — Calificación Técnica/Presupuestal',      # U   20
    'Fase C — Intercambio de Valor (Lead Magnet)',      # V   21
    'Fase D — Llamada a la Acción (CTA)',               # W   22
    'Objeción: "Es caro"',                             # X   23
    'Objeción: "Lo pienso / Lo voy a pensar"',         # Y   24
    'Objeción: "¿Por qué con ustedes?"',               # Z   25
    'Promociones vigentes (separadas por ";")',         # AA  26
    'Notas adicionales'                                 # AB  27
  ].freeze

  SECTION_FORMATS = [
    { cols: 0..0,   bg: '#C00000', fg: 'white' }, # A: rojo — ID crítico
    { cols: 1..5,   bg: '#4472C4', fg: 'white' }, # B–F: azul — perfil del producto
    { cols: 6..8,   bg: '#70AD47', fg: 'white' }, # G–I: verde claro — buyer persona
    { cols: 9..18,  bg: '#7030A0', fg: 'white' }, # J–S: morado — atributos y beneficios (máx 5)
    { cols: 19..22, bg: '#17375E', fg: 'white' }, # T–W: teal — flujo de calificación
    { cols: 23..25, bg: '#ED7D31', fg: 'white' }, # X–Z: naranja — objeciones (3 universales)
    { cols: 26..27, bg: '#FFC000', fg: 'black' }  # AA–AB: amarillo — extras
  ].freeze

  # Example row derived from the Honda blueprint (industry-agnostic reference)
  EXAMPLE_ROW = [
    'honda_mantenimiento',
    'Plan de Mantenimiento Oficial Honda',
    'Servicios Automotrices / Aftersales',
    'El único mantenimiento con refacciones y técnicos certificados Honda que protege tu garantía y alarga la vida de tu vehículo — con precio transparente antes de llegar al taller.',
    'Precio fijo por intervalo de kilometraje (cada 10,000 km o 12 meses). Varía por modelo, año y transmisión.',
    'MXN por servicio / por intervalo de kilometraje',
    'Propietarios de vehículos Honda en México, cualquier modelo, con 6 meses o más de uso.',
    'No saber cuándo ni cuánto costará el siguiente servicio; miedo a cobros sorpresa o a que un taller externo les anule la garantía.',
    'Tener su Honda siempre en óptimas condiciones, con la tranquilidad de que el costo es justo y predecible.',
    'Precio fijo publicado por modelo/año/km',
    'El cliente conoce el costo exacto antes de ir al taller — sin sorpresas ni negociaciones incómodas.',
    'Más de 15 operaciones incluidas en cada servicio (aceite, filtros, frenos, suspensión, inyectores, etc.)',
    'Una sola visita cubre todo lo que el auto necesita — ahorra tiempo y evita revisitas.',
    'Técnicos y refacciones certificadas Honda',
    'La garantía del vehículo permanece vigente — elimina el riesgo de perderla por servicio en taller externo.',
    'Programa de condiciones severas disponible (cada 5,000 km / 6 meses)',
    'El cliente que maneja en condiciones exigentes recibe atención personalizada — protege el motor en escenarios de alto desgaste.',
    'Válido para todos los modelos Honda (City, HRV, CRV, Accord, Pilot, etc.)',
    'Un solo agente puede atender a cualquier propietario Honda sin importar el modelo que tenga.',
    '¡Hola! Para orientarte mejor con tu plan de mantenimiento Honda, ¿me puedes decir qué modelo y año tiene tu vehículo?',
    '¿Cuántos kilómetros aproximados tiene tu Honda actualmente? Así te digo exactamente qué servicio te corresponde y cuánto cuesta.',
    'Tengo la ficha completa de tu servicio con todos los trabajos incluidos y el precio exacto. ¿Te la envío aquí mismo por WhatsApp para que la revises antes de tu cita?',
    '¿Quieres que te agende una cita con tu distribuidor Honda más cercano para este servicio?',
    'Entiendo. La diferencia es que aquí el servicio incluye más de 15 operaciones, refacciones originales Honda y técnicos certificados — todo lo que mantiene vigente tu garantía. Un taller externo puede ser más barato hoy, pero si algo falla, Honda no cubre el costo.',
    'Claro, sin presión. Solo considera que Honda recomienda el servicio cada 10,000 km o 12 meses. Si ya se cumplió el plazo, cada semana que pasa puede afectar el aceite o los filtros. ¿Quieres que te guarde el precio de hoy para cuando decidas?',
    'Puedes ir a otro taller, pero los talleres externos no usan refacciones originales certificadas por Honda, lo que puede dejar sin efecto tu garantía de fábrica. Con el distribuidor oficial tienes respaldo total del fabricante.',
    nil,
    nil
  ].freeze

  def generate
    io = StringIO.new
    workbook = WriteXLSX.new(io)

    section_formats = build_section_formats(workbook)
    example_format  = workbook.add_format(italic: 1, bg_color: '#E7E6E6', border: 1, text_wrap: 1)

    worksheet = workbook.add_worksheet('Perfiles de IA')
    worksheet.freeze_panes(1, 2)

    COLUMN_HEADERS.each_with_index do |header, col|
      fmt = section_formats[section_index_for(col)]
      worksheet.write(0, col, header, fmt)
    end

    EXAMPLE_ROW.each_with_index do |value, col|
      next if value.nil?

      worksheet.write_string(1, col, value.to_s, example_format)
    end

    apply_column_widths(worksheet)
    add_instructions_sheet(workbook)

    workbook.close
    io.string
  end

  private

  def build_section_formats(workbook)
    SECTION_FORMATS.map do |s|
      workbook.add_format(
        bold: 1,
        bg_color: s[:bg],
        color: s[:fg],
        border: 1,
        text_wrap: 0
      )
    end
  end

  def section_index_for(col)
    SECTION_FORMATS.index { |s| s[:cols].cover?(col) } || 0
  end

  def apply_column_widths(worksheet)
    worksheet.set_column(0, 0, 20)      # A: ID
    worksheet.set_column(1, 1, 32)      # B: Nombre
    worksheet.set_column(2, 2, 30)      # C: Categoría
    worksheet.set_column(3, 3, 55)      # D: USP
    worksheet.set_column(4, 4, 45)      # E: Modelo de precios
    worksheet.set_column(5, 5, 28)      # F: Unidad de valor
    worksheet.set_column(6, 8, 55)      # G-I: buyer persona
    worksheet.set_column(9, 18, 35)     # J-S: atributos/beneficios
    worksheet.set_column(19, 22, 65)    # T-W: flujo de calificación
    worksheet.set_column(23, 25, 65)    # X-Z: objeciones
    worksheet.set_column(26, 26, 65)    # AA: promociones
    worksheet.set_column(27, 27, 50)    # AB: notas
  end

  INSTRUCTION_SECTIONS = [
    {
      heading: 'Descripción', style: :section,
      lines: [
        'Este archivo define cómo el agente de IA presenta cada producto: a quién, cómo y qué responder ante objeciones.',
        'No reemplaza los datos del catálogo — los enriquece con argumentarios de venta, buyer personas y scripts de calificación.',
        'Aplica a cualquier industria: software, salud, automotriz, bienes raíces, servicios, educación, etc.'
      ]
    },
    {
      heading: 'Secciones del template', style: :section,
      lines: [
        '  Rojo    (A)     — ID del producto. REQUERIDO. Si está vacío, se genera UUID automáticamente.',
        '  Azul    (B–F)   — Perfil del producto: nombre, categoría, USP, modelo de precios, unidad de medida.',
        '  Verde   (G–I)   — Buyer persona: segmento objetivo, problema principal (pain point) y deseo aspiracional (gain).',
        '  Morado  (J–S)   — Matriz de atributos y beneficios: hasta 5 pares "Lo que es" / "Lo que logra".',
        '  Teal    (T–W)   — Flujo de calificación y cierre: 4 fases del script del agente.',
        '                      Fase A: Diagnóstico de situación.',
        '                      Fase B: Calificación técnica o presupuestal.',
        '                      Fase C: Intercambio de valor — ofrece ficha técnica, demo, cotizador, etc.',
        '                      Fase D: Llamada a la acción (agendar cita, prueba gratis, visita).',
        '  Naranja (X–Z)   — Manejo de objeciones: 3 respuestas universales (Es caro / Lo pienso / Competencia).',
        '  Amarillo(AA–AB) — Promociones vigentes y notas adicionales.'
      ]
    },
    {
      heading: 'Reglas de formato', style: :section,
      lines: [
        '  Modelo de Precios (E): campo de texto libre. Ej: "$799/mes o $8,390/año", "Precio fijo por km", "Cotización personalizada".',
        '  Unidad de Medida/Valor (F): campo de texto libre. Ej: "MXN", "USD por usuario/mes", "m²", "por servicio".',
        '  Atributos/beneficios (J–S): si dejas un par en blanco, ese par se omite. No es necesario llenar los 5.',
        '  Promociones (AA): separa múltiples valores con punto y coma (;) sin espacios extra. Ej: "Desc. 20%;Envío gratis".',
        '  Textos largos: sin límite de caracteres. El agente los lee completos.'
      ]
    },
    {
      heading: 'Flujo de calificación — cómo llenarlo', style: :bold,
      lines: [
        '  Fase A (T): ¿Qué pregunta hace el agente para entender la situación actual del cliente?',
        '  Fase B (U): ¿Qué pregunta hace para calificar el presupuesto o identificar la necesidad técnica?',
        '  Fase C (V): ¿Qué material ofrece el agente a cambio del contacto del cliente? (ficha técnica, demo, cotizador).',
        '  Fase D (W): ¿Cuál es el llamado a la acción final? (Agendar cita, prueba gratis, visita al negocio).',
        '  Si alguna fase no aplica a tu producto, déjala en blanco — el agente usará su criterio para ese paso.'
      ]
    },
    {
      heading: 'Carga incremental — no necesitas llenar todo a la vez', style: :bold,
      lines: [
        '  Puedes cargar solo buyer persona (G–I) esta semana y las objeciones la próxima.',
        '  Cada sección se reemplaza de forma atómica: si cargas objeciones, se reemplaza la sección completa.',
        '  Las secciones que no tocas se preservan intactas en el perfil existente del producto.',
        '  Orden sugerido: 1) Buyer persona (G–I), 2) Objeciones (X–Z), 3) Flujo (T–W), 4) Atributos (J–S).'
      ]
    },
    {
      heading: 'Advertencia sobre secciones con múltiples campos', style: :bold,
      lines: [
        '  Si actualizas cualquier objeción (X, Y o Z), debes rellenar TODAS las que quieras conservar.',
        '  Las celdas en blanco dentro de una sección activa se eliminan del perfil.',
        '  El mismo comportamiento aplica a flujo de calificación y atributos/beneficios.'
      ]
    },
    {
      heading: 'Cómo eliminar la fila de ejemplo', style: :bold,
      lines: ['  Borra la fila 2 (el ejemplo de Honda Mantenimiento) antes de subir tu propio archivo.']
    },
    {
      heading: 'Campos requeridos para productos nuevos (sin ID en base de datos)', style: :bold,
      lines: [
        '  Si el ID del Producto (A) no existe en el catálogo, se creará un producto nuevo.',
        '  Para productos nuevos es requerido: Nombre del Producto/Servicio (B).',
        '  Categoría de Mercado (C) es opcional pero recomendado para facilitar búsquedas.'
      ]
    }
  ].freeze

  def add_instructions_sheet(workbook)
    instructions = workbook.add_worksheet('Instrucciones')
    formats = {
      title:   workbook.add_format(bold: 1, size: 14),
      section: workbook.add_format(bold: 1, size: 12),
      bold:    workbook.add_format(bold: 1)
    }

    row = 0
    instructions.write(row, 0, 'Plantilla de Perfiles de IA — Catálogo de Productos', formats[:title])
    row += 2

    INSTRUCTION_SECTIONS.each do |section|
      row = write_instruction_section(instructions, row, section, formats)
    end

    instructions.set_column(0, 0, 120)
  end

  def write_instruction_section(sheet, row, section, formats)
    sheet.write(row, 0, section[:heading], formats[section[:style]])
    row += 1
    section[:lines].each do |line|
      sheet.write(row, 0, line)
      row += 1
    end
    row + 1
  end
end
