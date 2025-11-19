# frozen_string_literal: true

class Whatsapp::GroupService
  pattr_initialize [:conversation!]

  def create_group
    return unless should_create_group?

    whapi_payload = build_group_payload
    response = send_create_group_request(whapi_payload)

    process_response(response)
  end

  private

  def should_create_group?
    inbox.auto_assignment_config&.dig('assignment_type') == 'group' &&
      conversation.assignee&.phone_number.present? &&
      conversation.contact&.phone_number.present?
  end

  def build_group_payload
    {
      subject: group_subject,
      participants: group_participants
    }
  end

  def group_subject
    "Conversación ##{conversation.display_id} - #{inbox.name}"
  end

  def group_participants
    participants = []

    # Agregar número del agente asignado
    if conversation.assignee&.phone_number.present?
      participants << format_phone_number(conversation.assignee.phone_number)
    end

    # Agregar número del cliente
    if conversation.contact&.phone_number.present?
      participants << format_phone_number(conversation.contact.phone_number)
    end

    participants.compact.uniq
  end

  def send_create_group_request(payload)
    HTTParty.post(
      "#{whapi_api_url}/groups",
      headers: whapi_headers,
      body: payload.to_json
    )
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP GROUP] Error creating group: #{e.message}"
    nil
  end

  def process_response(response)
    return nil unless response&.success?

    parsed_response = JSON.parse(response.body)
    group_id = parsed_response['group_id'] || parsed_response['id']
    participants = parsed_response['participants'] || []

    if group_id.present?
      Rails.logger.info "[WHATSAPP GROUP] Group created successfully: #{group_id}"

      # Mapear los IDs de Whapi con nuestros contactos
      mapped_participants = map_participants_to_contacts(participants)
      participant_whapi_ids = participants.map { |p| p['id'] }.compact

      # Actualizar metadata de la conversación
      update_conversation_metadata(group_id, participant_whapi_ids, mapped_participants)

      # Crear ContactInbox para el grupo
      create_group_contact_inbox(group_id)

      group_id
    else
      Rails.logger.error "[WHATSAPP GROUP] No group_id in response: #{response.body}"
      nil
    end
  rescue JSON::ParserError => e
    Rails.logger.error "[WHATSAPP GROUP] Error parsing response: #{e.message}"
    nil
  end

  def update_conversation_metadata(group_id, participant_ids, mapped_participants)
    conversation.additional_attributes ||= {}
    conversation.additional_attributes['whatsapp_group_id'] = group_id
    conversation.additional_attributes['type'] = 'group'
    conversation.additional_attributes['participant_ids'] = participant_ids
    conversation.additional_attributes['participants'] = mapped_participants
    conversation.save!
  end

  def create_group_contact_inbox(group_id)
    # Crear ContactInbox para el grupo con el source_id del grupo
    return if inbox.contact_inboxes.exists?(source_id: group_id)

    inbox.contact_inboxes.create!(
      contact_id: conversation.contact_id,
      source_id: group_id
    )

    Rails.logger.info "[WHATSAPP GROUP] ContactInbox created for group: #{group_id}"
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP GROUP] Error creating group contact inbox: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  def map_participants_to_contacts(participants)
    # Mapear los participantes de Whapi con nuestros contactos locales
    participants.map do |participant|
      whapi_id = participant['id']
      phone = participant['phone'] || extract_phone_from_whapi_id(whapi_id)

      # Intentar encontrar el contacto por teléfono
      contact = find_contact_by_phone(phone)

      {
        'whapi_id' => whapi_id,
        'phone' => phone,
        'contact_id' => contact&.id,
        'user_id' => find_user_by_phone(phone)&.id
      }
    end.compact
  end

  def extract_phone_from_whapi_id(whapi_id)
    # Los IDs de Whapi tienen formato: 266507686797389@lid
    # Extraer solo la parte numérica
    whapi_id.to_s.split('@').first
  end

  def find_contact_by_phone(phone)
    return nil if phone.blank?

    formatted_phone = format_phone_number(phone)
    # Buscar contacto por número formateado (solo números)
    inbox.account.contacts.find do |contact|
      next unless contact.phone_number.present?

      format_phone_number(contact.phone_number) == formatted_phone
    end
  end

  def find_user_by_phone(phone)
    return nil if phone.blank?

    formatted_phone = format_phone_number(phone)
    # Buscar usuario por número formateado (solo números)
    inbox.account.users.find do |user|
      next unless user.phone_number.present?

      format_phone_number(user.phone_number) == formatted_phone
    end
  end

  def format_phone_number(phone)
    # Remover el + si existe y dejar solo números
    phone.to_s.gsub(/[^0-9]/, '')
  end

  def whapi_api_url
    ENV.fetch('WHAPI_GATE_URL', 'https://gate.whapi.cloud')
  end

  def whapi_headers
    {
      'Authorization' => "Bearer #{ENV.fetch('WHAPI_ADMIN_CHANNEL_TOKEN')}",
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
  end

  def inbox
    @inbox ||= conversation.inbox
  end
end
