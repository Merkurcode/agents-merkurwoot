class Webhooks::ElevenLabsController < ActionController::API
  before_action :verify_secret, only: [:process_payload]
  before_action :verify_post_call_signature, only: [:post_call]
  before_action :set_account, only: [:process_payload]

  def process_payload
    Rails.logger.info("[ElevenLabs] Payload recibido: #{params.to_unsafe_hash.slice('agent_id', 'caller_id', 'called_number', 'call_sid', 'conversation_id')}")

    contact = find_or_create_contact
    Rails.logger.info("[ElevenLabs] Contacto ##{contact.id} (#{contact.phone_number}) — nuevo: #{contact.previously_new_record?}")

    inbox = find_or_create_inbox
    Rails.logger.info("[ElevenLabs] Inbox ##{inbox.id} '#{inbox.name}'")

    contact_inbox = find_or_create_contact_inbox(contact, inbox)
    Rails.logger.info("[ElevenLabs] ContactInbox ##{contact_inbox.id} source_id=#{contact_inbox.source_id}")

    conversation = find_or_create_open_conversation(contact, inbox, contact_inbox)
    Rails.logger.info("[ElevenLabs] Conversación ##{conversation.id} display_id=#{conversation.display_id} status=#{conversation.status}")

    update_contact_attributes(contact)
    update_conversation_attributes(conversation)

    render json: {
      type: 'conversation_initiation_client_data',
      dynamic_variables: {
        contact_id: contact.id.to_s,
        account_id: @account.id.to_s,
        customer_name: contact.previously_new_record? ? nil : contact.name,
        conversation_id: conversation.id.to_s,
        display_id: conversation.display_id.to_s,
        account_name: @account.name,
        received_survey_id: inbox.survey_id.to_s
      }
    }, status: :ok
  rescue StandardError => e
    Rails.logger.error("[ElevenLabs] Error: #{e.class} — #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def post_call
    data = params[:data] || {}
    type = params[:type]

    Rails.logger.info("[ElevenLabs][PostCall] type=#{type} conversation_id=#{data[:conversation_id]}")

    case type
    when 'post_call_transcription'
      handle_transcription(data)
    when 'post_call_audio'
      handle_audio(data)
    else
      Rails.logger.info("[ElevenLabs][PostCall] Tipo ignorado: #{type}")
    end

    head :ok
  rescue StandardError => e
    Rails.logger.error("[ElevenLabs][PostCall] Error: #{e.class} — #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  # ─── Autenticación ────────────────────────────────────────────────────────

  def verify_secret
    secret = ENV.fetch('ELEVEN_LABS_WEBHOOK_SECRET', nil)
    provided = request.headers['X-ElevenLabs-Secret']

    Rails.logger.info("[ElevenLabs] verify_secret — secret configurado: #{secret.present?}, header presente: #{provided.present?}")

    return if secret.present? && ActiveSupport::SecurityUtils.secure_compare(secret, provided.to_s)

    Rails.logger.warn('[ElevenLabs] Autenticación fallida — secret no coincide o ausente')
    render json: { error: 'Unauthorized' }, status: :unauthorized
  end

  def verify_post_call_signature
    secret = ENV.fetch('ELEVEN_LABS_POST_CALL_SECRET', nil)
    sig_header = request.headers['ElevenLabs-Signature']

    return render json: { error: 'Unauthorized' }, status: :unauthorized if secret.blank? || sig_header.blank?

    parts = sig_header.split(',').each_with_object({}) do |part, hash|
      key, value = part.split('=', 2)
      hash[key] = value
    end

    timestamp = parts['t']
    signature = parts['v0']

    return render json: { error: 'Unauthorized' }, status: :unauthorized if timestamp.blank? || signature.blank?

    if (Time.now.to_i - timestamp.to_i).abs > 300
      Rails.logger.warn('[ElevenLabs][PostCall] Timestamp fuera de ventana — posible replay attack')
      return render json: { error: 'Unauthorized' }, status: :unauthorized
    end

    raw_body = request.body.read
    request.body.rewind

    expected = OpenSSL::HMAC.hexdigest('SHA256', secret, "#{timestamp}.#{raw_body}")

    return if ActiveSupport::SecurityUtils.secure_compare(expected, signature)

    Rails.logger.warn('[ElevenLabs][PostCall] Firma HMAC inválida')
    render json: { error: 'Unauthorized' }, status: :unauthorized
  end

  # ─── process_payload: account ─────────────────────────────────────────────

  def set_account
    Rails.logger.info("[ElevenLabs] Buscando account con eleven_labs_agent_id=#{params[:agent_id]}")
    @account = Account.find_by(eleven_labs_agent_id: params[:agent_id])

    if @account
      Rails.logger.info("[ElevenLabs] Account encontrado: ##{@account.id} '#{@account.name}'")
    else
      Rails.logger.warn("[ElevenLabs] Ningún account tiene agent_id=#{params[:agent_id]}")
      render json: { error: 'Account not found for this agent' }, status: :not_found
    end
  end

  # ─── post_call: handlers ─────────────────────────────────────────────────

  def handle_transcription(data)
    conversation = find_conversation_for_post_call(data)
    unless conversation
      Rails.logger.warn("[ElevenLabs][PostCall] Conversación no encontrada (conversation_id=#{data[:conversation_id]})")
      return
    end

    update_post_call_attributes(conversation, data)

    start_time = data.dig(:metadata, :start_time_unix_secs)
    ElevenLabs::ImportTranscriptJob.perform_later(conversation.id, data[:transcript].as_json, start_time)
    Rails.logger.info("[ElevenLabs][PostCall] Conversación ##{conversation.id} actualizada — transcript import encolado")
  end

  def handle_audio(data)
    conversation = find_conversation_for_post_call(data)
    unless conversation
      Rails.logger.warn("[ElevenLabs][PostCall] Conversación no encontrada para audio (eleven_labs_conversation_id=#{data[:conversation_id]})")
      return
    end

    full_audio = data[:full_audio]
    return Rails.logger.warn('[ElevenLabs][PostCall] full_audio vacío') if full_audio.blank?

    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(Base64.decode64(full_audio)),
      filename: "call_#{data[:conversation_id]}.mp3",
      content_type: 'audio/mpeg'
    )

    ElevenLabs::ImportAudioJob.perform_later(conversation.id, blob.id)
    Rails.logger.info("[ElevenLabs][PostCall] Audio blob ##{blob.id} creado — import encolado para conversación ##{conversation.id}")
  end

  # Intenta resolver la conversación primero via dynamic_variables (transcription),
  # con fallback a eleven_labs_conversation_id (audio, que no incluye dynamic_variables).
  def find_conversation_for_post_call(data)
    find_conversation_from_dynamic_variables(data) ||
      Conversation.find_by(eleven_labs_conversation_id: data[:conversation_id])
  end

  def find_conversation_from_dynamic_variables(data)
    vars = data.dig(:conversation_initiation_client_data, :dynamic_variables) || {}
    account_id = vars[:account_id]
    conversation_id = vars[:conversation_id]

    return nil if account_id.blank? || conversation_id.blank?

    Account.find_by(id: account_id)&.conversations&.find_by(id: conversation_id)
  end

  # ─── process_payload helpers ──────────────────────────────────────────────

  def find_or_create_contact
    contact = @account.contacts.find_by(phone_number: caller_phone)
    contact ||= @account.contacts.create!(
      name: caller_phone,
      phone_number: caller_phone
    )
    contact
  end

  def caller_phone
    params[:caller_id]
  end

  def find_or_create_inbox
    channel = Channel::VoiceAgent.find_or_create_by!(account_id: @account.id)
    channel.inbox || create_inbox_for_channel(channel)
  rescue ActiveRecord::RecordNotUnique
    Channel::VoiceAgent.find_by!(account_id: @account.id).inbox
  end

  def create_inbox_for_channel(channel)
    Inbox.create!(
      account: @account,
      channel: channel,
      name: 'Agente de Voz',
      channel_type: 'Channel::VoiceAgent'
    )
  end

  def find_or_create_contact_inbox(contact, inbox)
    ContactInboxBuilder.new(
      contact: contact,
      inbox: inbox,
      source_id: params[:call_sid].presence || SecureRandom.uuid
    ).perform
  end

  def find_or_create_open_conversation(_contact, _inbox, contact_inbox)
    eleven_labs_conversation_id = params[:conversation_id]

    if eleven_labs_conversation_id.present?
      existing = Conversation.find_by(eleven_labs_conversation_id: eleven_labs_conversation_id)
      return existing if existing
    end

    ConversationBuilder.new(params: ActionController::Parameters.new({}), contact_inbox: contact_inbox).perform
  end

  def update_contact_attributes(contact)
    attrs = {
      'caller_id' => params[:caller_id],
      'agent_id' => params[:agent_id]
    }.compact_blank

    return if attrs.blank?

    contact.update!(custom_attributes: (contact.custom_attributes || {}).merge(attrs))
  end

  def update_conversation_attributes(conversation)
    additional = {
      'call_sid' => params[:call_sid],
      'called_number' => params[:called_number],
      'caller_id' => params[:caller_id]
    }.compact_blank

    updates = { additional_attributes: (conversation.additional_attributes || {}).merge(additional) }
    updates[:eleven_labs_conversation_id] = params[:conversation_id] if params[:conversation_id].present?

    conversation.update!(updates)
  end

  # ─── post_call helpers ────────────────────────────────────────────────────

  def update_post_call_attributes(conversation, data)
    metadata = data[:metadata] || {}
    analysis = data[:analysis] || {}

    post_call_attrs = {
      'call_status' => data[:status],
      'call_duration_secs' => metadata[:call_duration_secs],
      'call_successful' => analysis[:call_successful]
    }.compact_blank

    updates = {
      additional_attributes: (conversation.additional_attributes || {}).merge(post_call_attrs)
    }

    summary = analysis[:transcript_summary]
    updates[:summary] = summary if meaningful_summary?(summary)

    conversation.update!(updates)
  end

  UNINFORMATIVE_SUMMARIES = [
    "Summary couldn't be generated for this call."
  ].freeze

  def meaningful_summary?(summary)
    summary.present? && UNINFORMATIVE_SUMMARIES.exclude?(summary)
  end
end
