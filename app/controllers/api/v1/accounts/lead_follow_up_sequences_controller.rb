class Api::V1::Accounts::LeadFollowUpSequencesController < Api::V1::Accounts::BaseController
  before_action :set_inbox, only: [:index, :create, :available_templates]
  before_action :set_sequence, only: [:show, :update, :destroy, :activate, :deactivate]

  def index
    @sequences = Current.account.lead_follow_up_sequences.includes(:inbox)
    @sequences = @sequences.where(inbox_id: @inbox.id) if @inbox
  end

  def show; end

  def create
    @sequence = Current.account.lead_follow_up_sequences.new(sequence_params)
    if @sequence.save
      render :show, status: :created
    else
      render json: { errors: @sequence.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    @sequence.update!(sequence_params)
    render :show
  end

  def destroy
    @sequence.deactivate! if @sequence.active?
    @sequence.destroy!
    head :no_content
  end

  def activate
    @sequence.activate!
    render :show
  end

  def deactivate
    @sequence.deactivate!
    render :show
  end

  def available_templates
    inbox = Current.account.inboxes.find(params[:inbox_id])

    unless inbox.inbox_type == 'Whatsapp'
      return render json: { error: 'Inbox must be WhatsApp' }, status: :unprocessable_entity
    end

    templates = inbox.channel.message_templates || []

    render json: {
      templates: templates.map do |t|
        {
          name: t['name'],
          language: t['language'],
          status: t['status'],
          category: t['category'],
          components: t['components']
        }
      end
    }
  end

  def preview_eligible
    inbox_id = params[:inbox_id]
    sequence_id = params[:sequence_id]
    trigger_conditions = params[:trigger_conditions] || {}
    stop_on_contact_reply = params.dig(:settings, :stop_on_contact_reply) || false

    unless inbox_id
      return render json: { error: 'inbox_id is required' }, status: :unprocessable_entity
    end

    query = LeadRetargeting::EligibleConversationsQueryBuilder.call(
      account_id: Current.account.id,
      inbox_id: inbox_id,
      trigger_conditions: trigger_conditions,
      include_cancelled: true,
      stop_on_contact_reply: stop_on_contact_reply,
      sequence_id: sequence_id
    )

    total_count = query.count

    page = params[:page]&.to_i || 1
    per_page = [params[:per_page]&.to_i || 20, 100].min
    conversations = query
                    .includes(:contact)
                    .order(created_at: :desc)
                    .limit(per_page)
                    .offset((page - 1) * per_page)

    render json: {
      total_count: total_count,
      conversations: conversations.map do |conv|
        {
          id: conv.id,
          display_id: conv.display_id,
          status: conv.status,
          created_at: conv.created_at,
          contact: {
            id: conv.contact&.id,
            name: conv.contact&.name,
            phone_number: conv.contact&.phone_number
          }
        }
      end,
      page: page,
      per_page: per_page,
      total_pages: (total_count / per_page.to_f).ceil
    }
  rescue StandardError => e
    Rails.logger.error "Error previewing eligible conversations: #{e.message}"
    render json: { error: 'Failed to preview eligible conversations' }, status: :internal_server_error
  end

  private

  def set_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id]) if params[:inbox_id]
  end

  def set_sequence
    @sequence = Current.account.lead_follow_up_sequences.find(params[:id])
  end

  def sequence_params
    permitted = params.require(:lead_follow_up_sequence).permit(
      :name,
      :description,
      :active,
      :inbox_id
    )

    # Extract complex nested structures using to_unsafe_h to bypass strong parameters
    raw_params = params[:lead_follow_up_sequence]
    permitted[:steps] = raw_params[:steps].map(&:to_unsafe_h) if raw_params[:steps].present?
    permitted[:trigger_conditions] = raw_params[:trigger_conditions].to_unsafe_h if raw_params[:trigger_conditions].present?
    permitted[:settings] = raw_params[:settings].to_unsafe_h if raw_params[:settings].present?

    permitted
  end
end
