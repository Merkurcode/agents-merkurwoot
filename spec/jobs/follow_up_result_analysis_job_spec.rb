# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FollowUpResultAnalysisJob do
  let(:account) { create(:account) }
  let(:whatsapp_channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
  let(:inbox) { create(:inbox, channel: whatsapp_channel, account: account) }
  let(:agent_bot) { create(:agent_bot, account: account, outgoing_url: 'https://bot.example.com/webhook') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:sequence) do
    create(:lead_follow_up_sequence, account: account, inbox: inbox,
                                     result_schema: [
                                       { 'key' => 'outcome', 'label' => 'Outcome', 'type' => 'select',
                                         'required' => true,
                                         'options' => [{ 'label' => 'Converted', 'value' => 'converted' }] }
                                     ])
  end
  let(:enrollment) { create(:sequence_enrollment, :completed, conversation: conversation, lead_follow_up_sequence: sequence) }

  before do
    create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot)
  end

  describe '#perform' do
    context 'when all conditions are met' do
      it 'enqueues AgentBots::WebhookJob with correct event type' do
        expect(AgentBots::WebhookJob).to receive(:perform_later).with(
          agent_bot.outgoing_url,
          hash_including(event: 'lead_followup.result_analysis_request'),
          :lead_followup_result_analysis,
          anything
        )

        described_class.new.perform(enrollment.id)
      end

      it 'includes enrollment data in the payload' do
        expect(AgentBots::WebhookJob).to receive(:perform_later).with(
          anything,
          hash_including(
            enrollment: hash_including(
              id: enrollment.id,
              status: 'completed',
              completion_reason: 'Contact replied'
            )
          ),
          anything,
          anything
        )

        described_class.new.perform(enrollment.id)
      end

      it 'includes result_schema in the payload' do
        expect(AgentBots::WebhookJob).to receive(:perform_later).with(
          anything,
          hash_including(result_schema: sequence.result_schema),
          anything,
          anything
        )

        described_class.new.perform(enrollment.id)
      end

      it 'uses a deterministic idempotency key' do
        expected_key = Digest::SHA256.hexdigest("result-analysis-#{enrollment.id}")

        expect(AgentBots::WebhookJob).to receive(:perform_later).with(
          anything, anything, anything, expected_key
        )

        described_class.new.perform(enrollment.id)
      end
    end

    context 'early returns' do
      it 'does nothing when enrollment does not exist' do
        expect(AgentBots::WebhookJob).not_to receive(:perform_later)
        described_class.new.perform(0)
      end

      it 'does nothing when result_schema is blank' do
        sequence.update!(result_schema: [])
        expect(AgentBots::WebhookJob).not_to receive(:perform_later)
        described_class.new.perform(enrollment.id)
      end

      it 'does nothing when inbox has no agent_bot' do
        AgentBotInbox.where(inbox: inbox).destroy_all
        expect(AgentBots::WebhookJob).not_to receive(:perform_later)
        described_class.new.perform(enrollment.id)
      end

      it 'does nothing when agent_bot has no outgoing_url' do
        agent_bot.update!(outgoing_url: '')
        expect(AgentBots::WebhookJob).not_to receive(:perform_later)
        described_class.new.perform(enrollment.id)
      end
    end
  end
end
