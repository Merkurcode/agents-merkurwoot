# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LeadFollowUpSequence do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { expect(described_class.reflect_on_association(:inbox)).not_to be_nil }
    it { is_expected.to have_many(:conversation_follow_ups).dependent(:destroy) }
    it { is_expected.to have_many(:enrollment_result_values).dependent(:destroy_async) }
  end

  describe 'validations' do
    let(:account) { create(:account) }
    let(:whatsapp_channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
    let(:whatsapp_inbox) { create(:inbox, channel: whatsapp_channel, account: account) }

    it { is_expected.to validate_presence_of(:name) }
    it 'requires an inbox' do
      seq = build(:lead_follow_up_sequence, account: create(:account))
      seq.inbox = nil
      expect(seq.valid?).to be false
    end

    context 'when inbox is not WhatsApp' do
      let(:website_channel) { create(:channel_widget, account: account) }
      let(:website_inbox) { create(:inbox, channel: website_channel, account: account) }
      let(:sequence) { build(:lead_follow_up_sequence, account: account, inbox: website_inbox) }

      it 'adds error for non-messaging inbox' do
        expect(sequence.valid?).to be false
        expect(sequence.errors[:inbox]).to include('must be a WhatsApp, SMS, or Email inbox')
      end
    end

    context 'when source_type is notion_database' do
      # Use widget inbox to avoid WhatsApp sync_templates side-effect;
      # notion_database source skips the top-level inbox channel validation.
      let(:widget_channel) { create(:channel_widget, account: account) }
      let(:widget_inbox) { create(:inbox, channel: widget_channel, account: account) }

      def build_notion_sequence(field_mappings)
        build(:lead_follow_up_sequence,
              account: account,
              inbox: widget_inbox,
              source_type: 'notion_database',
              source_config: {
                'notion_database_id' => 'db-123',
                'field_mappings' => field_mappings
              },
              steps: [])
      end

      it 'is valid when only phone_number is mapped' do
        seq = build_notion_sequence({ 'phone_number' => 'Phone' })
        seq.valid?
        expect(seq.errors[:source_config]).not_to include('must have at least phone_number or email field mapping')
      end

      it 'is valid when only email is mapped' do
        seq = build_notion_sequence({ 'email' => 'Email' })
        seq.valid?
        expect(seq.errors[:source_config]).not_to include('must have at least phone_number or email field mapping')
      end

      it 'is valid when both phone_number and email are mapped' do
        seq = build_notion_sequence({ 'phone_number' => 'Phone', 'email' => 'Email' })
        seq.valid?
        expect(seq.errors[:source_config]).not_to include('must have at least phone_number or email field mapping')
      end

      it 'is invalid when neither phone_number nor email is mapped' do
        seq = build_notion_sequence({ 'name' => 'Name' })
        seq.valid?
        expect(seq.errors[:source_config]).to include('must have at least phone_number or email field mapping')
      end
    end

    context 'when result_schema has invalid fields' do
      let(:whatsapp_sequence) { build(:lead_follow_up_sequence, account: account, inbox: whatsapp_inbox) }

      it 'is valid with an empty result_schema' do
        whatsapp_sequence.result_schema = []
        expect(whatsapp_sequence.valid?).to be true
      end

      it 'is valid with a well-formed schema' do
        whatsapp_sequence.result_schema = [
          { 'key' => 'outcome', 'label' => 'Outcome', 'type' => 'select',
            'required' => true, 'options' => [{ 'label' => 'Converted', 'value' => 'converted' }] }
        ]
        expect(whatsapp_sequence.valid?).to be true
      end

      it 'is invalid when a field is missing key' do
        whatsapp_sequence.result_schema = [{ 'label' => 'Outcome', 'type' => 'text' }]
        expect(whatsapp_sequence.valid?).to be false
        expect(whatsapp_sequence.errors[:result_schema]).to include('field missing key')
      end

      it 'is invalid when a field is missing label' do
        whatsapp_sequence.result_schema = [{ 'key' => 'outcome', 'type' => 'text' }]
        expect(whatsapp_sequence.valid?).to be false
        expect(whatsapp_sequence.errors[:result_schema]).to include('field missing label')
      end

      it 'is invalid when field type is not supported' do
        whatsapp_sequence.result_schema = [{ 'key' => 'outcome', 'label' => 'Outcome', 'type' => 'image' }]
        expect(whatsapp_sequence.valid?).to be false
        expect(whatsapp_sequence.errors[:result_schema]).to include("invalid type 'image'")
      end

      it 'is invalid when select field has no options' do
        whatsapp_sequence.result_schema = [
          { 'key' => 'outcome', 'label' => 'Outcome', 'type' => 'select', 'options' => [] }
        ]
        expect(whatsapp_sequence.valid?).to be false
        expect(whatsapp_sequence.errors[:result_schema]).to include("select field 'outcome' needs options")
      end

      it 'accepts all supported types' do
        %w[text select number boolean].each do |type|
          field = { 'key' => 'f', 'label' => 'F', 'type' => type }
          field['options'] = [{ 'label' => 'Yes', 'value' => 'yes' }] if type == 'select'
          whatsapp_sequence.result_schema = [field]
          whatsapp_sequence.valid?
          expect(whatsapp_sequence.errors[:result_schema]).not_to include("invalid type '#{type}'")
        end
      end
    end

    context 'when steps is not an array' do
      let(:sequence) do
        build(:lead_follow_up_sequence, account: account, inbox: whatsapp_inbox,
                                        steps: 'not an array')
      end

      it 'adds error' do
        expect(sequence.valid?).to be false
        expect(sequence.errors[:steps]).to include('must be an array')
      end
    end

    context 'when step has invalid type' do
      let(:sequence) do
        build(:lead_follow_up_sequence, account: account, inbox: whatsapp_inbox,
                                        steps: [{ 'id' => '1', 'type' => 'invalid_type', 'enabled' => true }])
      end

      it 'adds error' do
        expect(sequence.valid?).to be false
        expect(sequence.errors[:steps]).to include('step at index 0 has invalid type: invalid_type')
      end
    end

    context 'when wait step has invalid config' do
      let(:sequence) do
        build(:lead_follow_up_sequence, account: account, inbox: whatsapp_inbox,
                                        steps: [{
                                          'id' => '1',
                                          'type' => 'wait',
                                          'enabled' => true,
                                          'config' => { 'delay_value' => 0, 'delay_type' => 'invalid' }
                                        }])
      end

      it 'adds errors for invalid delay config' do
        expect(sequence.valid?).to be false
        expect(sequence.errors[:steps]).to include('wait step at index 0 must have delay_value > 0')
        expect(sequence.errors[:steps]).to include('wait step at index 0 must have delay_type: minutes, hours, or days')
      end
    end

    context 'when send_message step is missing template_config' do
      let(:sequence) do
        build(:lead_follow_up_sequence, account: account, inbox: whatsapp_inbox,
                                        steps: [{
                                          'id' => '1',
                                          'type' => 'send_message',
                                          'enabled' => true,
                                          'config' => { 'closed_window_action' => 'send_template' }
                                        }])
      end

      it 'adds error for missing template_config' do
        expect(sequence.valid?).to be false
        expect(sequence.errors[:steps]).to include(
          'message step at index 0 requires template_config when closed_window_action is send_template'
        )
      end
    end
  end

  describe 'scopes' do
    let(:account) { create(:account) }
    let(:whatsapp_channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
    let(:whatsapp_inbox) { create(:inbox, channel: whatsapp_channel, account: account) }
    let!(:active_sequence) { create(:lead_follow_up_sequence, account: account, inbox: whatsapp_inbox, active: true) }
    let!(:inactive_sequence) { create(:lead_follow_up_sequence, account: account, inbox: whatsapp_inbox, active: false) }

    describe '.active' do
      it 'returns only active sequences' do
        expect(described_class.active).to include(active_sequence)
        expect(described_class.active).not_to include(inactive_sequence)
      end
    end
  end

  describe '#activate!' do
    let(:account) { create(:account) }
    let(:whatsapp_channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
    let(:whatsapp_inbox) { create(:inbox, channel: whatsapp_channel, account: account) }
    let(:sequence) { create(:lead_follow_up_sequence, account: account, inbox: whatsapp_inbox, active: false) }

    it 'sets active to true' do
      sequence.activate!
      expect(sequence.reload.active).to be true
    end
  end

  describe '#deactivate!' do
    let(:account) { create(:account) }
    let(:whatsapp_channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
    let(:whatsapp_inbox) { create(:inbox, channel: whatsapp_channel, account: account) }
    let(:sequence) { create(:lead_follow_up_sequence, account: account, inbox: whatsapp_inbox, active: true) }
    let(:conversation) { create(:conversation, account: account, inbox: whatsapp_inbox) }
    let!(:active_follow_up) do
      create(:conversation_follow_up, conversation: conversation,
                                      lead_follow_up_sequence: sequence, status: 'active')
    end
    let!(:completed_follow_up) do
      create(:conversation_follow_up, conversation: create(:conversation, account: account, inbox: whatsapp_inbox),
                                      lead_follow_up_sequence: sequence, status: 'completed')
    end

    it 'sets active to false' do
      sequence.deactivate!
      expect(sequence.reload.active).to be false
    end

    it 'cancels all active follow-ups' do
      sequence.deactivate!
      expect(active_follow_up.reload.status).to eq('cancelled')
    end

    it 'does not affect completed follow-ups' do
      sequence.deactivate!
      expect(completed_follow_up.reload.status).to eq('completed')
    end
  end

  describe '#step_by_id' do
    let(:account) { create(:account) }
    let(:whatsapp_channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
    let(:whatsapp_inbox) { create(:inbox, channel: whatsapp_channel, account: account) }
    let(:sequence) do
      create(:lead_follow_up_sequence, account: account, inbox: whatsapp_inbox,
                                       steps: [
                                         { 'id' => 'step_1', 'type' => 'wait', 'enabled' => true,
                                           'config' => { 'delay_value' => 2, 'delay_type' => 'hours' } },
                                         { 'id' => 'step_2', 'type' => 'add_label', 'enabled' => true }
                                       ])
    end

    it 'returns step by id' do
      step = sequence.step_by_id('step_1')
      expect(step).to eq({ 'id' => 'step_1', 'type' => 'wait', 'enabled' => true, 'config' => { 'delay_value' => 2, 'delay_type' => 'hours' } })
    end

    it 'returns nil for non-existent step' do
      step = sequence.step_by_id('non_existent')
      expect(step).to be_nil
    end
  end

  describe '#enabled_steps' do
    let(:account) { create(:account) }
    let(:whatsapp_channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
    let(:whatsapp_inbox) { create(:inbox, channel: whatsapp_channel, account: account) }
    let(:sequence) do
      create(:lead_follow_up_sequence, account: account, inbox: whatsapp_inbox,
                                       steps: [
                                         { 'id' => 'step_1', 'type' => 'wait', 'enabled' => true,
                                           'config' => { 'delay_value' => 2, 'delay_type' => 'hours' } },
                                         { 'id' => 'step_2', 'type' => 'add_label', 'enabled' => false },
                                         { 'id' => 'step_3', 'type' => 'add_label', 'enabled' => true }
                                       ])
    end

    it 'returns only enabled steps' do
      enabled = sequence.enabled_steps
      expect(enabled.length).to eq(2)
      expect(enabled.map { |s| s['id'] }).to eq(%w[step_1 step_3])
    end
  end

  describe '#render_param_value' do
    let(:account) { create(:account) }
    let(:whatsapp_channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
    let(:whatsapp_inbox) { create(:inbox, channel: whatsapp_channel, account: account) }
    let(:sequence) { create(:lead_follow_up_sequence, account: account, inbox: whatsapp_inbox) }
    let(:contact) { create(:contact, account: account, name: 'John Doe', phone_number: '+1234567890') }
    let(:conversation) { create(:conversation, account: account, inbox: whatsapp_inbox, contact: contact) }
    let(:context) do
      {
        contact: contact,
        conversation: conversation,
        account: account,
        inbox: whatsapp_inbox
      }
    end

    it 'renders contact variables' do
      result = sequence.render_param_value('Hello {{contact.name}}', context)
      expect(result).to eq('Hello John Doe')
    end

    it 'renders conversation variables' do
      result = sequence.render_param_value('Conversation #{{conversation.display_id}}', context)
      expect(result).to eq("Conversation ##{conversation.display_id}")
    end

    it 'renders account variables' do
      result = sequence.render_param_value('Account: {{account.name}}', context)
      expect(result).to eq("Account: #{account.name}")
    end

    it 'renders multiple variables' do
      result = sequence.render_param_value('Hi {{contact.name}}, your phone is {{contact.phone_number}}', context)
      expect(result).to eq('Hi John Doe, your phone is +1234567890')
    end

    it 'handles unknown variables gracefully' do
      result = sequence.render_param_value('Value: {{unknown.variable}}', context)
      expect(result).to eq('Value: [Unknown variable: unknown.variable]')
    end

    it 'renders custom attributes' do
      contact.update!(custom_attributes: { 'city' => 'New York' })
      result = sequence.render_param_value('City: {{custom_attr.city}}', context)
      expect(result).to eq('City: New York')
    end
  end
end
