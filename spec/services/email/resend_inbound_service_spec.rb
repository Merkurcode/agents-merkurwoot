require 'rails_helper'

describe Email::ResendInboundService do
  let(:account) { create(:account) }
  let(:email_channel) { create(:channel_email, account: account) }
  let(:inbox) { create(:inbox, account: account, channel: email_channel) }
  let(:contact) { create(:contact, account: account, email: 'lead@example.com') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:outgoing_message_id) { 'sent-123@mail.example.com' }
  let!(:outgoing_message) do
    create(:message, conversation: conversation, message_type: 'outgoing', source_id: outgoing_message_id)
  end

  let(:email_id) { '56761188-7520-42d8-8898-ff6fc54ce618' }

  def webhook(overrides = {})
    base = {
      'type' => 'email.received',
      'data' => {
        'email_id' => email_id,
        'from' => 'lead@example.com',
        'to' => ['inbox@notification.merkur.la'],
        'subject' => 'Re: hello'
      }
    }
    base.deep_merge(overrides)
  end

  def resend_api_response(overrides = {})
    {
      'id' => email_id,
      'from' => 'lead@example.com',
      'to' => ['inbox@notification.merkur.la'],
      'subject' => 'Re: hello',
      'text' => 'Tengo una duda sobre el producto',
      'html' => '<p>Tengo una duda sobre el producto</p>',
      'headers' => {
        'message-id' => '<reply-456@example.com>',
        'in-reply-to' => "<#{outgoing_message_id}>"
      }
    }.merge(overrides)
  end

  def stub_resend_fetch(payload, status: 200)
    response = instance_double(HTTParty::Response,
                               success?: status.between?(200, 299),
                               code: status,
                               body: payload.to_json,
                               parsed_response: payload)
    allow(HTTParty).to receive(:get).and_return(response)
  end

  before do
    stub_const('ENV', ENV.to_h.merge('RESEND_API_KEY' => 're_test'))
  end

  describe '#perform' do
    context 'when event is not email.received' do
      it 'returns without fetching from Resend' do
        allow(HTTParty).to receive(:get)
        described_class.new(webhook('type' => 'email.delivered')).perform
        expect(HTTParty).not_to have_received(:get)
      end
    end

    context 'when matching by In-Reply-To from API response' do
      before { stub_resend_fetch(resend_api_response) }

      it 'creates an incoming message in the original conversation' do
        expect { described_class.new(webhook).perform }
          .to change { conversation.messages.where(message_type: 'incoming').count }.by(1)

        msg = conversation.messages.where(message_type: 'incoming').last
        expect(msg.content).to eq('Tengo una duda sobre el producto')
        expect(msg.source_id).to eq('reply-456@example.com')
        expect(msg.content_attributes['email']['subject']).to eq('Re: hello')
      end

      it 'is idempotent on same message_id' do
        described_class.new(webhook).perform
        expect { described_class.new(webhook).perform }
          .not_to change { conversation.messages.where(message_type: 'incoming').count }
      end
    end

    context 'when In-Reply-To does not match, fallback to plus-addressing' do
      let(:plus_address) { "reply+#{conversation.uuid}@notification.merkur.la" }

      before do
        stub_resend_fetch(resend_api_response(
                            'headers' => { 'message-id' => '<reply-789@example.com>', 'in-reply-to' => '<unknown@example.com>' }
                          ))
      end

      it 'finds the conversation by uuid in the plus-address from webhook to' do
        payload = webhook('data' => { 'to' => [plus_address] })
        expect { described_class.new(payload).perform }
          .to change { conversation.messages.where(message_type: 'incoming').count }.by(1)
      end
    end

    context 'when neither strategy matches' do
      before do
        stub_resend_fetch(resend_api_response(
                            'headers' => { 'message-id' => '<x@example.com>', 'in-reply-to' => '<missing@example.com>' }
                          ))
      end

      it 'raises ConversationNotFound' do
        payload = webhook('data' => { 'to' => ['random@notification.merkur.la'] })
        expect { described_class.new(payload).perform }
          .to raise_error(Email::ResendInboundService::ConversationNotFound)
      end
    end

    context 'when Resend API returns 404 for both endpoints, falls back to webhook data' do
      let(:plus_address) { "reply+#{conversation.uuid}@notification.merkur.la" }

      before { stub_resend_fetch({ 'error' => 'not found' }, status: 404) }

      it 'still creates the incoming message using webhook payload data' do
        payload = webhook(
          'data' => {
            'to' => [plus_address],
            'subject' => 'Re: hello',
            'message_id' => '<webhook-msg-id@example.com>'
          }
        )
        expect { described_class.new(payload).perform }
          .to change { conversation.messages.where(message_type: 'incoming').count }.by(1)

        msg = conversation.messages.where(message_type: 'incoming').last
        expect(msg.source_id).to eq('webhook-msg-id@example.com')
        expect(msg.content_attributes['email']['subject']).to eq('Re: hello')
      end
    end

    context 'when only html body is present' do
      before { stub_resend_fetch(resend_api_response('text' => nil, 'html' => '<p>Hola</p>')) }

      it 'creates a message with sanitized text content' do
        described_class.new(webhook).perform
        msg = conversation.messages.where(message_type: 'incoming').last
        expect(msg.content).to eq('Hola')
      end
    end
  end
end
