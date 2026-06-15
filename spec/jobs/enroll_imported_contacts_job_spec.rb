# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EnrollImportedContactsJob do
  let(:account) { create(:account) }
  let(:whatsapp_channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
  let(:whatsapp_inbox) { create(:inbox, channel: whatsapp_channel, account: account) }
  let(:job) { described_class.new }

  def build_sequence(source_config = {})
    seq = build(:lead_follow_up_sequence,
                account: account,
                inbox: whatsapp_inbox,
                source_type: 'imported_contacts',
                source_config: source_config,
                steps: [{
                  'id' => 'first_1',
                  'type' => 'first_contact',
                  'enabled' => true,
                  'config' => { 'channel' => 'whatsapp', 'inbox_id' => whatsapp_inbox.id }
                }])
    seq.save!(validate: false)
    seq
  end

  describe '#perform' do
    it 'does nothing when sequence is not found' do
      expect { described_class.perform_now(0) }.not_to raise_error
    end

    it 'does nothing when sequence is inactive' do
      sequence = build_sequence
      sequence.update_column(:active, false)
      expect(job).not_to receive(:create_conversation_with_first_contact)
      described_class.perform_now(sequence.id)
    end

    it 'does nothing when source_type is not imported_contacts' do
      sequence = build_sequence
      sequence.update_column(:source_type, 'existing_conversations')
      expect(job).not_to receive(:create_conversation_with_first_contact)
      described_class.perform_now(sequence.id)
    end

    it 'enqueues next batch when contacts fill the batch size' do
      stub_const('EnrollImportedContactsJob::BATCH_SIZE', 1)
      sequence = build_sequence
      create(:contact, account: account, phone_number: '+521234567890')
      create(:contact, account: account, phone_number: '+529876543210')

      allow_any_instance_of(described_class).to receive(:create_conversation_with_first_contact).and_return(nil)

      expect(described_class).to receive(:perform_later).with(sequence.id, 1)
      described_class.perform_now(sequence.id, 0)
    end
  end

  describe '#build_contacts_query (via send)' do
    subject(:query) { job.send(:build_contacts_query, sequence) }

    context 'with no filters' do
      let(:sequence) { build_sequence }

      before { create_list(:contact, 3, account: account) }

      it 'returns all account contacts' do
        expect(query.count).to eq(3)
      end
    end

    context 'with require_phone filter' do
      let(:sequence) { build_sequence('require_phone' => true) }

      before do
        create(:contact, account: account, phone_number: '+521234567890')
        create(:contact, account: account, phone_number: nil)
      end

      it 'returns only contacts with a phone number' do
        expect(query.count).to eq(1)
      end
    end

    context 'with require_email filter' do
      let(:sequence) { build_sequence('require_email' => true) }

      before do
        create(:contact, account: account, email: 'a@example.com')
        create(:contact, account: account, email: nil)
      end

      it 'returns only contacts with an email' do
        expect(query.count).to eq(1)
      end
    end

    context 'with created_at newer_than filter' do
      let(:sequence) { build_sequence('created_at_filter' => { 'enabled' => true, 'operator' => 'newer_than', 'value' => 7 }) }

      before do
        create(:contact, account: account, created_at: 3.days.ago)
        create(:contact, account: account, created_at: 30.days.ago)
      end

      it 'returns only recently created contacts' do
        expect(query.count).to eq(1)
      end
    end

    context 'with created_at older_than filter' do
      let(:sequence) { build_sequence('created_at_filter' => { 'enabled' => true, 'operator' => 'older_than', 'value' => 7 }) }

      before do
        create(:contact, account: account, created_at: 3.days.ago)
        create(:contact, account: account, created_at: 30.days.ago)
      end

      it 'returns only older contacts' do
        expect(query.count).to eq(1)
      end
    end

    context 'with custom_attribute_filters' do
      let(:sequence) do
        build_sequence('custom_attribute_filters' => [
                         { 'attribute_key' => 'plan', 'operator' => 'equal_to', 'value' => 'pro' }
                       ])
      end

      before do
        create(:contact, account: account, custom_attributes: { 'plan' => 'pro' })
        create(:contact, account: account, custom_attributes: { 'plan' => 'free' })
        create(:contact, account: account, custom_attributes: {})
      end

      it 'returns only contacts matching the custom attribute' do
        expect(query.count).to eq(1)
      end
    end

    context 'with is_present custom attribute filter' do
      let(:sequence) do
        build_sequence('custom_attribute_filters' => [
                         { 'attribute_key' => 'plan', 'operator' => 'is_present' }
                       ])
      end

      before do
        create(:contact, account: account, custom_attributes: { 'plan' => 'pro' })
        create(:contact, account: account, custom_attributes: {})
      end

      it 'returns only contacts with the attribute present' do
        expect(query.count).to eq(1)
      end
    end
  end
end
