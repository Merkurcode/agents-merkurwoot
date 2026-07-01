#!/usr/bin/env ruby
# frozen_string_literal: true

# Importa contactos + conversaciones desde el CSV de leads exportado.
#
# Uso:
#   INBOX_ID=6 DRY_RUN=true rails runner import_leads_with_conversations.rb
#
# Variables de entorno:
#   CSV_PATH                Ruta al CSV (default: ENV o el export en ~/Downloads)
#   INBOX_ID                ID del inbox de WhatsApp destino (default 6 en local)
#   DRY_RUN                 "true" => solo simula y reporta, no escribe (default true)
#   SUPPRESS_EVENTS         "true" => desactiva dispatcher (automatizaciones, webhooks,
#                           follow-ups, notificaciones) durante el import (default true)
#   ROWS                    Lista 1-based de filas de datos a procesar, ej "4,5,6,7,8"
#                           (si se omite, usa OFFSET/LIMIT sobre filas WHATSAPP_WEB)
#   SKIP_CONVERSATION_ROWS  Filas que crean SOLO el contacto (sin conversación), ej "7"
#   OFFSET, LIMIT           Paginación para corridas masivas (cuando ROWS está vacío)
#
# Seguridad:
#   - Los mensajes outgoing se crean con un source_id sintético => SendOnWhatsappService
#     los considera "originados en el canal" y NO los reenvía por WhatsApp.
#   - Con SUPPRESS_EVENTS, el dispatcher se reemplaza por uno nulo => no se disparan
#     reglas de automatización, webhooks, secuencias de follow-up ni notificaciones.
#   - Idempotente: cada conversación se marca con additional_attributes["import_row_key"];
#     si ya existe una con esa key, se omite (re-ejecutable sin duplicar).

require 'csv'
require 'set'

# ---------------------------------------------------------------------------
# Configuración
# ---------------------------------------------------------------------------
CSV_PATH = ENV['CSV_PATH'].presence ||
           '/home/eddy/Downloads/8eb64f7f-2512-4118-882e-8182cf3a3e58_20260616235144.csv'
INBOX_ID = (ENV['INBOX_ID'].presence || '6').to_i
DRY_RUN = ENV.fetch('DRY_RUN', 'true') != 'false'
SUPPRESS_EVENTS = ENV.fetch('SUPPRESS_EVENTS', 'true') != 'false'
ONLY_ROWS = ENV['ROWS'].to_s.split(',').map { |s| s.strip.to_i }.reject(&:zero?).to_set
SKIP_CONV_ROWS = ENV['SKIP_CONVERSATION_ROWS'].to_s.split(',').map { |s| s.strip.to_i }.reject(&:zero?).to_set
OFFSET = ENV['OFFSET'].to_i
LIMIT = ENV['LIMIT'].present? ? ENV['LIMIT'].to_i : nil
VERBOSE = ENV['VERBOSE'] == 'true'
# Etapas que NO se importan (ni contacto ni conversación). Default: proveedores/internos/placeholder.
EXCLUDE_STAGES = ENV.fetch('EXCLUDE_STAGES', 'proveedores,status #11,chats internos')
                    .split(',').map { |s| s.strip.downcase }.reject(&:blank?).to_set

abort "CSV no encontrado: #{CSV_PATH}" unless File.exist?(CSV_PATH)

inbox = Inbox.find_by(id: INBOX_ID)
abort "Inbox #{INBOX_ID} no existe" if inbox.nil?
abort "Inbox #{INBOX_ID} (#{inbox.name}) no es de WhatsApp (#{inbox.channel_type})" unless inbox.channel_type == 'Channel::Whatsapp'

account = inbox.account

# Guardia opcional: si se pasa ACCOUNT_ID, debe coincidir con la cuenta dueña del inbox.
if ENV['ACCOUNT_ID'].present? && account.id != ENV['ACCOUNT_ID'].to_i
  abort "El inbox #{INBOX_ID} pertenece a la cuenta #{account.id}, no a ACCOUNT_ID=#{ENV['ACCOUNT_ID']}. Abortando."
end

puts '=' * 70
puts "Import leads -> Inbox ##{inbox.id} #{inbox.name.inspect} (account #{account.id})"
puts "CSV: #{CSV_PATH}"
puts "DRY_RUN=#{DRY_RUN} | SUPPRESS_EVENTS=#{SUPPRESS_EVENTS}"
puts "ROWS=#{ONLY_ROWS.to_a.sort.inspect} | SKIP_CONVERSATION_ROWS=#{SKIP_CONV_ROWS.to_a.sort.inspect}" if ONLY_ROWS.any?
puts "OFFSET=#{OFFSET} LIMIT=#{LIMIT.inspect}" if ONLY_ROWS.empty?
puts "EXCLUDE_STAGES=#{EXCLUDE_STAGES.to_a.inspect}" if EXCLUDE_STAGES.any?
puts '=' * 70

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def phone_like?(lead)
  lead.match?(/\A\d{11,15}\z/)
end

def valid_email?(email)
  email.present? && email.match?(Devise.email_regexp)
end

def parse_time(value)
  Time.zone.parse(value.to_s)
rescue ArgumentError, TypeError
  nil
end

# Reemplaza el dispatcher por uno nulo para que NO se disparen listeners.
def with_events_suppressed(enabled)
  return yield unless enabled

  null = Object.new
  def null.dispatch(*); end
  def null.load_listeners; end
  original = Rails.configuration.dispatcher
  Rails.configuration.dispatcher = null
  begin
    yield
  ensure
    Rails.configuration.dispatcher = original
  end
end

stats = Hash.new(0)

# ---------------------------------------------------------------------------
# Proceso de una fila
# ---------------------------------------------------------------------------
process_row = lambda do |row, data_row_no|
  lead = row['Lead'].to_s.strip
  name = row['Name'].to_s.strip
  stage = row['Stage Name'].to_s.strip
  funnel = row['Funnel Name'].to_s.strip
  email = row['Email'].to_s.strip
  tags = row['Tags'].to_s.strip
  agent_name = row['User Assigned'].to_s.strip
  first_msg = row['First Message'].to_s.strip
  last_msg = row['Last Message'].to_s.strip
  created_raw = row['Created At'].to_s.strip
  last_action_raw = row['Last Action At'].to_s.strip

  created_at = parse_time(created_raw) || Time.current
  last_action_at = parse_time(last_action_raw) || created_at
  skip_conversation = SKIP_CONV_ROWS.include?(data_row_no)

  # Etapas excluidas: no se importan (ni contacto ni conversación)
  if EXCLUDE_STAGES.include?(stage.downcase)
    stats[:skipped_excluded_stage] += 1
    puts "[SKIP stage=#{stage.inspect}] row##{data_row_no} lead=#{lead}" if VERBOSE
    return
  end

  # Identidad del contacto
  if phone_like?(lead)
    phone_number = "+#{lead}"
    identifier = nil
  else
    phone_number = nil
    identifier = lead
  end
  source_id = lead
  email_to_use = valid_email?(email) ? email : nil

  import_row_key = "#{lead}|#{created_raw}"

  contact_attributes = {
    name: name.presence,
    phone_number: phone_number,
    email: email_to_use,
    identifier: identifier,
    custom_attributes: { imported_from: 'csv_leads', csv_agent_assigned: agent_name, csv_funnel: funnel }.compact_blank
  }.compact

  label = "row##{data_row_no} lead=#{lead} #{name.inspect}"

  if DRY_RUN
    existing_ci = inbox.contact_inboxes.find_by(source_id: source_id)
    reuse = existing_ci&.contact.present?
    contact_state = reuse ? "REUSARIA contacto ##{existing_ci.contact_id}" : 'CREARIA contacto'
    dup_conv = Conversation.where(account_id: account.id)
                           .where("additional_attributes->>'import_row_key' = ?", import_row_key).exists?
    msg_count = [first_msg.present?, last_msg.present? && last_msg != first_msg].count(true)
    conv_state = if skip_conversation
                   'SIN conversacion (skip)'
                 elsif dup_conv
                   'OMITIRIA conversacion (ya importada)'
                 else
                   "CREARIA conversacion resuelta (stage=#{stage.inspect}, msgs=#{msg_count})"
                 end

    stats[:dry_rows] += 1
    stats[reuse ? :dry_reuse_contact : :dry_new_contact] += 1
    stats[:dry_non_phone_lead] += 1 unless phone_number
    stats[:dry_invalid_email] += 1 if email.present? && email_to_use.nil?
    if skip_conversation
      stats[:dry_skip_conversation] += 1
    elsif dup_conv
      stats[:dry_dup_conversation] += 1
    else
      stats[:dry_with_conversation] += 1
      stats[:dry_zero_messages] += 1 if msg_count.zero?
      stats[:dry_total_messages] += msg_count
    end

    puts "[DRY] #{label} | phone=#{phone_number.inspect} | #{contact_state} | #{conv_state}" if VERBOSE
    return
  end

  # --- Contacto + contact_inbox (dedup nativo por source_id/phone/email/identifier) ---
  contact_inbox = ContactInboxWithContactBuilder.new(
    inbox: inbox,
    contact_attributes: contact_attributes,
    source_id: source_id
  ).perform
  contact = contact_inbox.contact
  stats[:contacts_touched] += 1
  puts "  #{label} -> contacto ##{contact.id} (#{contact.phone_number || contact.identifier})"

  # Etiquetas desde Tags
  if tags.present?
    label_list = tags.split(/[;,]/).map(&:strip).reject(&:blank?)
    contact.add_labels(label_list) if label_list.any?
  end

  if skip_conversation
    puts '    -> SOLO contacto (SKIP_CONVERSATION_ROWS)'
    stats[:contacts_only] += 1
    return
  end

  # Idempotencia: no duplicar la conversación de esta misma fila
  if Conversation.where(account_id: account.id)
                 .where("additional_attributes->>'import_row_key' = ?", import_row_key).exists?
    puts '    -> conversacion ya importada, OMITIDA'
    stats[:conversations_skipped] += 1
    return
  end

  # pipeline_status (embudo) a partir del Stage Name
  pipeline_status = nil
  if stage.present?
    pipeline_status = account.pipeline_statuses
                             .find_or_create_by!(name: stage.downcase, pipeline_type: 'conversation')
  end

  conversation = Conversation.create!(
    account_id: account.id,
    inbox_id: inbox.id,
    contact_id: contact.id,
    contact_inbox_id: contact_inbox.id,
    additional_attributes: { import_row_key: import_row_key, imported_from: 'csv_leads', csv_agent_assigned: agent_name },
    created_at: created_at,
    updated_at: last_action_at,
    last_activity_at: last_action_at
  )

  # Conversation tiene before_create :determine_conversation_status (=> pending si el
  # inbox tiene bot) y :assign_pipeline_status (=> primer embudo). Forzamos el estado
  # final con update_columns para saltar esos callbacks.
  conversation.update_columns(
    status: Conversation.statuses[:resolved],
    pipeline_status_id: pipeline_status&.id
  )
  stats[:conversations_created] += 1

  # Mensajes: el PRIMERO es entrante (del cliente) y el ÚLTIMO saliente (del agente).
  # Se insertan con insert_all para SALTAR todos los callbacks de Message: nada de
  # SendReplyJob (no se reenvía a WhatsApp), ni mensajes de actividad, ni eventos.
  # El source_id sintético queda como marca.
  msg_specs = []
  msg_specs << [first_msg, created_at, :incoming] if first_msg.present?
  msg_specs << [last_msg, last_action_at, :outgoing] if last_msg.present? && last_msg != first_msg

  message_rows = msg_specs.each_with_index.map do |(content, ts, direction), idx|
    incoming = direction == :incoming
    {
      account_id: account.id,
      inbox_id: inbox.id,
      conversation_id: conversation.id,
      message_type: Message.message_types[direction],
      content_type: Message.content_types[:text],
      content: content,
      status: Message.statuses[:sent],
      sender_type: incoming ? 'Contact' : nil,
      sender_id: incoming ? contact.id : nil,
      source_id: "csv_import:#{lead}:#{idx}",
      private: false,
      created_at: ts,
      updated_at: ts
    }
  end

  if message_rows.any?
    Message.insert_all(message_rows)
    stats[:messages_created] += message_rows.size
  end

  puts "    -> conversacion ##{conversation.display_id} resuelta (stage=#{stage.inspect}, #{msg_specs.size} msg)"
end

# ---------------------------------------------------------------------------
# Iteración del CSV
# ---------------------------------------------------------------------------
with_events_suppressed(SUPPRESS_EVENTS) do
  data_row_no = 0
  processed = 0

  CSV.foreach(CSV_PATH, headers: true) do |row|
    data_row_no += 1
    next unless row['Channel'].to_s.strip == 'WHATSAPP_WEB'

    if ONLY_ROWS.any?
      next unless ONLY_ROWS.include?(data_row_no)
    else
      next if data_row_no <= OFFSET
      break if LIMIT && processed >= LIMIT
    end

    begin
      process_row.call(row, data_row_no)
    rescue StandardError => e
      stats[:errors] += 1
      puts "  [ERROR] row##{data_row_no} lead=#{row['Lead']}: #{e.class}: #{e.message}"
    end
    processed += 1
  end
end

# ---------------------------------------------------------------------------
# Resumen
# ---------------------------------------------------------------------------
puts '=' * 70
puts 'RESUMEN'
stats.sort.each { |k, v| puts "  #{k}: #{v}" }
puts "  (DRY_RUN: no se escribió nada)" if DRY_RUN
puts '=' * 70
