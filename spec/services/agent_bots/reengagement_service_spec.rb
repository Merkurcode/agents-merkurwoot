require 'rails_helper'

RSpec.describe AgentBots::ReengagementService do
  let(:account) { create(:account) }
  let(:agent_bot) { create(:agent_bot, account: account) }
  let(:whatsapp_channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud',
                              sync_templates: false, validate_provider_config: false)
  end
  let(:whatsapp_inbox) { create(:inbox, channel: whatsapp_channel, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Ana López', phone_number: '+5215551234567') }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: whatsapp_inbox, source_id: '5215551234567') }
  let(:conversation) { create(:conversation, contact: contact, inbox: whatsapp_inbox, contact_inbox: contact_inbox, account: account) }
  let(:reengagement) { create(:conversation_reengagement, conversation: conversation, agent_bot: agent_bot) }

  let(:service) { described_class.new(reengagement) }

  before do
    allow(reengagement).to receive(:reengagement_config).and_return({ 'attempts' => [{ 'delay_value' => 5, 'delay_unit' => 'minutes' }] })
    allow(reengagement).to receive(:advance!).and_return(false)
    allow(reengagement).to receive(:stop_on_resolved?).and_return(false)
    allow(reengagement).to receive(:stop_on_agent_assigned?).and_return(false)
    allow(reengagement).to receive(:stop_on_any_reply?).and_return(false)
    allow(reengagement).to receive(:stop_keywords).and_return([[], false])
    allow(reengagement).to receive(:suppress!).and_return(true)
    allow(reengagement).to receive(:cancel!).and_return(true)
    allow(reengagement).to receive(:trigger_started_at).and_return(1.hour.ago)
    allow(reengagement).to receive(:current_attempt).and_return(0)
  end

  describe '#execute' do
    context 'when conversation is a non-WhatsApp channel' do
      let(:regular_inbox) { create(:inbox, account: account) }
      let(:regular_conversation) { create(:conversation, inbox: regular_inbox, account: account) }
      let(:regular_reengagement) { create(:conversation_reengagement, conversation: regular_conversation, agent_bot: agent_bot) }

      before do
        allow(regular_reengagement).to receive(:reengagement_config).and_return({ 'attempts' => [] })
        allow(regular_reengagement).to receive(:advance!).and_return(false)
        allow(regular_reengagement).to receive(:stop_on_resolved?).and_return(false)
        allow(regular_reengagement).to receive(:stop_on_agent_assigned?).and_return(false)
        allow(regular_reengagement).to receive(:stop_on_any_reply?).and_return(false)
        allow(regular_reengagement).to receive(:stop_keywords).and_return([[], false])
        allow(regular_reengagement).to receive(:trigger_started_at).and_return(1.hour.ago)
        allow(regular_reengagement).to receive(:current_attempt).and_return(0)
      end

      it 'fires webhook' do
        service = described_class.new(regular_reengagement)
        expect(AgentBots::WebhookJob).to receive(:perform_later)

        service.execute
      end
    end

    context 'when the conversation window is open (< 24h)' do
      before { allow(conversation).to receive(:can_reply?).and_return(true) }

      it 'fires webhook even without template configured' do
        expect(AgentBots::WebhookJob).to receive(:perform_later)

        service.execute
      end
    end

    context 'when the conversation window is closed (> 24h) and no template configured' do
      before do
        allow(conversation).to receive(:can_reply?).and_return(false)
        whatsapp_inbox.update!(reengagement_config: {})
      end

      it 'falls back to firing the webhook' do
        expect(AgentBots::WebhookJob).to receive(:perform_later)

        service.execute
      end
    end

    context 'when the conversation window is closed and template is configured but not approved' do
      let(:mock_provider_service) { instance_double(Whatsapp::Providers::WhatsappCloudService) }

      before do
        allow(conversation).to receive(:can_reply?).and_return(false)
        whatsapp_inbox.update!(reengagement_config: { 'template' => { 'name' => 'proactive_reengagement_40' } })
        allow(whatsapp_channel).to receive(:provider_service).and_return(mock_provider_service)
        allow(mock_provider_service).to receive(:get_template_status)
          .and_return({ success: true, template: { status: 'PENDING' } })
      end

      it 'falls back to firing the webhook' do
        expect(AgentBots::WebhookJob).to receive(:perform_later)

        service.execute
      end
    end

    context 'when the conversation window is closed and template is APPROVED' do
      let(:mock_provider_service) { instance_double(Whatsapp::Providers::WhatsappCloudService) }

      before do
        allow(conversation).to receive(:can_reply?).and_return(false)
        whatsapp_inbox.update!(reengagement_config: {
                                 'message' => 'Hola {{1}}, ¿en qué podemos ayudarte?',
                                 'language' => 'es_MX',
                                 'template' => { 'name' => 'proactive_reengagement_40' }
                               })
        allow(whatsapp_channel).to receive(:provider_service).and_return(mock_provider_service)
        allow(mock_provider_service).to receive(:get_template_status)
          .and_return({ success: true, template: { status: 'APPROVED' } })
        allow(mock_provider_service).to receive(:send_template).and_return('wamid_abc123')
      end

      it 'sends the template instead of firing the webhook' do
        expect(AgentBots::WebhookJob).not_to receive(:perform_later)
        expect(mock_provider_service).to receive(:send_template)

        service.execute
      end

      it 'creates an outgoing message record' do
        expect { service.execute }.to change { conversation.messages.count }.by(1)
        message = conversation.messages.last
        expect(message.message_type).to eq('outgoing')
        expect(message.content).to include('Ana López')
      end

      it 'renders the contact name in the message body' do
        service.execute
        message = conversation.messages.last
        expect(message.content).to eq('Hola Ana López, ¿en qué podemos ayudarte?')
      end

      it 'stores the meta message id as source_id' do
        service.execute
        message = conversation.messages.last
        expect(message.source_id).to eq('wamid_abc123')
      end

      it 'still advances the reengagement sequence' do
        expect(reengagement).to receive(:advance!)

        service.execute
      end

      it 'falls back to phone number when contact has no name' do
        contact.update!(name: nil)
        service.execute
        message = conversation.messages.last
        expect(message.content).to include('+5215551234567')
      end
    end

    context 'when template sending raises an error' do
      let(:mock_provider_service) { instance_double(Whatsapp::Providers::WhatsappCloudService) }

      before do
        allow(conversation).to receive(:can_reply?).and_return(false)
        whatsapp_inbox.update!(reengagement_config: {
                                 'message' => 'Hola {{1}}',
                                 'template' => { 'name' => 'proactive_reengagement_40' }
                               })
        allow(whatsapp_channel).to receive(:provider_service).and_return(mock_provider_service)
        allow(mock_provider_service).to receive(:get_template_status)
          .and_return({ success: true, template: { status: 'APPROVED' } })
        allow(mock_provider_service).to receive(:send_template).and_raise(StandardError, 'Meta API error')
      end

      it 'rescues the error and still advances the sequence' do
        expect(reengagement).to receive(:advance!)
        expect { service.execute }.not_to raise_error
      end
    end
  end
end
