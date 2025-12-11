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
