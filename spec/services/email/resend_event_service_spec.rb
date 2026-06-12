require 'rails_helper'

describe Email::ResendEventService do
  let(:account) { create(:account) }
  let(:channel) { create(:channel_email, account: account) }
  let(:inbox) { create(:inbox, account: account, channel: channel) }
  let(:contact) { create(:contact, account: account, email: 'lead@example.com') }
  let!(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }

  def event(type, data_overrides = {})
    {
      'type' => type,
      'created_at' => Time.current.iso8601,
      'data' => {
        'email_id' => SecureRandom.uuid,
        'from' => 'replies@notification.merkur.la',
        'to' => ['lead@example.com'],
        'subject' => 'Hola'
      }.merge(data_overrides)
    }
  end

  describe '#perform' do
    context 'when event is email.bounced (hard bounce)' do
      let(:payload) { event('email.bounced', 'bounce' => { 'type' => 'hard', 'message' => 'No such user' }) }

      it 'marks the contact with email_bounced and bounce reason' do
        described_class.new(payload).perform
        attrs = contact.reload.custom_attributes
        expect(attrs['email_bounced']).to be(true)
        expect(attrs['email_bounce_reason']).to eq('No such user')
        expect(attrs['email_bounced_at']).to be_present
      end

      it 'creates a private note in the most recent conversation' do
        expect { described_class.new(payload).perform }
          .to change { conversation.messages.where(private: true).count }.by(1)

        note = conversation.messages.where(private: true).last
        expect(note.content).to include('Bounce')
        expect(note.content).to include('No such user')
      end
    end

    context 'when event is email.bounced (soft bounce)' do
      let(:payload) { event('email.bounced', 'bounce' => { 'type' => 'soft', 'message' => 'Mailbox full' }) }

      it 'creates the private note but does NOT mark email_bounced' do
        described_class.new(payload).perform
        expect(contact.reload.custom_attributes['email_bounced']).to be_nil
        expect(conversation.messages.where(private: true).last.content).to include('Mailbox full')
      end
    end

    context 'when event is email.complained' do
      let(:payload) { event('email.complained') }

      it 'marks the contact as opted out with spam_complaint reason' do
        described_class.new(payload).perform
        attrs = contact.reload.custom_attributes
        expect(attrs['email_opted_out']).to be(true)
        expect(attrs['email_opt_out_reason']).to eq('spam_complaint')
        expect(attrs['email_opted_out_at']).to be_present
      end

      it 'creates a private note' do
        expect { described_class.new(payload).perform }
          .to change { conversation.messages.where(private: true).count }.by(1)
      end
    end

    context 'when event is email.delivered' do
      let(:payload) { event('email.delivered') }

      it 'logs without raising or mutating contact' do
        expect { described_class.new(payload).perform }.not_to raise_error
        expect(contact.reload.custom_attributes).not_to include('email_bounced', 'email_opted_out')
      end
    end

    context 'when event type is not handled' do
      let(:payload) { event('email.unknown') }

      it 'returns silently without changes' do
        expect { described_class.new(payload).perform }.not_to raise_error
        expect(conversation.messages.where(private: true).count).to eq(0)
      end
    end

    context 'when no contact matches the recipient' do
      let(:payload) { event('email.bounced', 'to' => ['unknown@example.com'], 'bounce' => { 'type' => 'hard' }) }

      it 'completes without raising' do
        expect { described_class.new(payload).perform }.not_to raise_error
      end
    end
  end
end
