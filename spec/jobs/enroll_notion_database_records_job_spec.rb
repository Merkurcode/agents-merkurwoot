# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EnrollNotionDatabaseRecordsJob do
  let(:account) { create(:account) }
  let(:email_channel) { create(:channel_email, account: account) }
  let(:email_inbox) { Inbox.find_by(channel: email_channel) }
  let(:job) { described_class.new }

  def build_sequence(field_mappings)
    seq = build(:lead_follow_up_sequence,
                account: account,
                inbox: email_inbox,
                source_type: 'notion_database',
                source_config: {
                  'notion_database_id' => 'db-123',
                  'field_mappings' => field_mappings
                },
                steps: [{
                  'id' => 'first_1',
                  'type' => 'first_contact',
                  'enabled' => true,
                  'config' => { 'channel' => 'email', 'inbox_id' => email_inbox.id }
                }])
    seq.save!(validate: false)
    seq
  end

  def notion_record(id: 'rec-1', phone: nil, email: nil, name: nil)
    properties = {}
    properties['Phone'] = { 'type' => 'phone_number', 'phone_number' => phone } if phone
    properties['Email'] = { 'type' => 'email', 'email' => email } if email
    properties['Name'] = { 'type' => 'title', 'title' => [{ 'plain_text' => name }] } if name
    { id: id, properties: properties }
  end

  describe '#find_or_create_contact (via send)' do
    subject(:find_or_create) { job.send(:find_or_create_contact, sequence, record) }

    context 'when record has phone only' do
      let(:sequence) { build_sequence('phone_number' => 'Phone', 'name' => 'Name') }
      let(:record) { notion_record(phone: '+5215512345678', name: 'Juan Pérez') }

      it 'creates a contact with phone' do
        expect { find_or_create }.to change(Contact, :count).by(1)
        expect(find_or_create.phone_number).to eq('+5215512345678')
      end
    end

    context 'when record has email only' do
      let(:sequence) { build_sequence('email' => 'Email', 'name' => 'Name') }
      let(:record) { notion_record(email: 'juan@example.com', name: 'Juan Pérez') }

      it 'creates a contact with email' do
        expect { find_or_create }.to change(Contact, :count).by(1)
        expect(find_or_create.email).to eq('juan@example.com')
      end

      it 'does not set phone_number' do
        contact = find_or_create
        expect(contact.phone_number).to be_nil
      end
    end

    context 'when record has both phone and email' do
      let(:sequence) { build_sequence('phone_number' => 'Phone', 'email' => 'Email') }
      let(:record) { notion_record(phone: '+5215512345678', email: 'juan@example.com') }

      it 'creates a contact with both' do
        contact = find_or_create
        expect(contact.phone_number).to eq('+5215512345678')
        expect(contact.email).to eq('juan@example.com')
      end
    end

    context 'when record has neither phone nor email' do
      let(:sequence) { build_sequence('name' => 'Name') }
      let(:record) { notion_record(name: 'Sin Contacto') }

      it 'returns nil and does not create a contact' do
        expect { find_or_create }.not_to change(Contact, :count)
        expect(find_or_create).to be_nil
      end
    end

    context 'when a contact with that phone already exists' do
      let(:sequence) { build_sequence('phone_number' => 'Phone') }
      let(:record) { notion_record(phone: '+5215512345678') }
      let!(:existing_contact) { create(:contact, account: account, phone_number: '+5215512345678') }

      it 'returns the existing contact without creating a new one' do
        expect { find_or_create }.not_to change(Contact, :count)
        expect(find_or_create.id).to eq(existing_contact.id)
      end
    end

    context 'when a contact with that email already exists (no phone in record)' do
      let(:sequence) { build_sequence('email' => 'Email') }
      let(:record) { notion_record(email: 'juan@example.com') }
      let!(:existing_contact) { create(:contact, account: account, email: 'juan@example.com') }

      it 'returns the existing contact without creating a new one' do
        expect { find_or_create }.not_to change(Contact, :count)
        expect(find_or_create.id).to eq(existing_contact.id)
      end
    end
  end

  describe '#generate_source_id_for_inbox (via send)' do
    subject(:generate) { job.send(:generate_source_id_for_inbox, phone, inbox, email: email) }

    context 'with WhatsApp inbox' do
      let(:whatsapp_channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
      let(:inbox) { create(:inbox, channel: whatsapp_channel, account: account) }

      context 'when phone is present' do
        let(:phone) { '+5215512345678' }
        let(:email) { nil }

        it 'strips the + prefix' do
          expect(generate).to eq('5215512345678')
        end
      end

      context 'when phone is nil but email is present' do
        let(:phone) { nil }
        let(:email) { 'fallback@example.com' }

        it 'falls back to email' do
          expect(generate).to eq('fallback@example.com')
        end
      end
    end

    context 'with Email inbox' do
      let(:inbox) { email_inbox }

      context 'when email is present' do
        let(:phone) { nil }
        let(:email) { 'contact@example.com' }

        it 'uses email as source_id' do
          expect(generate).to eq('contact@example.com')
        end
      end

      context 'when only phone is present' do
        let(:phone) { '+5215512345678' }
        let(:email) { nil }

        it 'falls back to phone' do
          expect(generate).to eq('+5215512345678')
        end
      end
    end
  end
end
