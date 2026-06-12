require 'rails_helper'

RSpec.describe 'Webhooks::ResendController', type: :request do
  describe 'POST /webhooks/resend/inbound' do
    let(:secret) { 'whsec_testsecret' }
    let(:payload) { { 'type' => 'email.received', 'data' => { 'from' => 'lead@example.com', 'to' => ['reply+abc@reply.example.com'] } }.to_json }
    let(:headers) do
      {
        'svix-id' => 'msg_test',
        'svix-timestamp' => Time.now.to_i.to_s,
        'svix-signature' => 'v1,sig'
      }
    end

    context 'with valid signature' do
      before do
        with_modified_env RESEND_INBOUND_WEBHOOK_SECRET: secret do
          allow_any_instance_of(Svix::Webhook).to receive(:verify).and_return(true)
        end
      end

      it 'invokes ResendInboundService and returns 200' do
        with_modified_env RESEND_INBOUND_WEBHOOK_SECRET: secret do
          allow_any_instance_of(Svix::Webhook).to receive(:verify).and_return(true)
          service = instance_double(Email::ResendInboundService, perform: nil)
          allow(Email::ResendInboundService).to receive(:new).and_return(service)

          post '/webhooks/resend/inbound', params: payload, headers: headers.merge('Content-Type' => 'application/json')

          expect(response).to have_http_status(:ok)
          expect(service).to have_received(:perform)
        end
      end

      it 'dispatches to ResendEventService for bounce/complaint events sent to the same endpoint' do
        with_modified_env RESEND_INBOUND_WEBHOOK_SECRET: secret do
          allow_any_instance_of(Svix::Webhook).to receive(:verify).and_return(true)
          event_service = instance_double(Email::ResendEventService, perform: nil)
          allow(Email::ResendEventService).to receive(:new).and_return(event_service)

          bounce_payload = { 'type' => 'email.bounced', 'data' => { 'to' => ['lead@example.com'], 'bounce' => { 'type' => 'hard' } } }.to_json
          post '/webhooks/resend/inbound', params: bounce_payload, headers: headers.merge('Content-Type' => 'application/json')

          expect(response).to have_http_status(:ok)
          expect(event_service).to have_received(:perform)
        end
      end

      it 'returns 200 when no conversation matches (so Resend stops retrying)' do
        with_modified_env RESEND_INBOUND_WEBHOOK_SECRET: secret do
          allow_any_instance_of(Svix::Webhook).to receive(:verify).and_return(true)
          allow_any_instance_of(Email::ResendInboundService)
            .to receive(:perform).and_raise(Email::ResendInboundService::ConversationNotFound, 'no match')

          post '/webhooks/resend/inbound', params: payload, headers: headers.merge('Content-Type' => 'application/json')

          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'with invalid signature' do
      it 'returns 401' do
        with_modified_env RESEND_INBOUND_WEBHOOK_SECRET: secret do
          allow_any_instance_of(Svix::Webhook).to receive(:verify).and_raise(Svix::WebhookVerificationError)

          post '/webhooks/resend/inbound', params: payload, headers: headers.merge('Content-Type' => 'application/json')

          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    context 'when secret is not configured' do
      it 'returns 401' do
        with_modified_env RESEND_INBOUND_WEBHOOK_SECRET: nil do
          post '/webhooks/resend/inbound', params: payload, headers: headers.merge('Content-Type' => 'application/json')

          expect(response).to have_http_status(:unauthorized)
        end
      end
    end
  end

  describe 'POST /webhooks/resend/events' do
    let(:secret) { 'whsec_testsecret' }
    let(:payload) { { 'type' => 'email.bounced', 'data' => { 'to' => ['lead@example.com'], 'bounce' => { 'type' => 'hard' } } }.to_json }
    let(:headers) do
      {
        'svix-id' => 'msg_test',
        'svix-timestamp' => Time.now.to_i.to_s,
        'svix-signature' => 'v1,sig'
      }
    end

    it 'invokes ResendEventService when signature is valid' do
      with_modified_env RESEND_INBOUND_WEBHOOK_SECRET: secret do
        allow_any_instance_of(Svix::Webhook).to receive(:verify).and_return(true)
        service = instance_double(Email::ResendEventService, perform: nil)
        allow(Email::ResendEventService).to receive(:new).and_return(service)

        post '/webhooks/resend/events', params: payload, headers: headers.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(:ok)
        expect(service).to have_received(:perform)
      end
    end

    it 'returns 401 with invalid signature' do
      with_modified_env RESEND_INBOUND_WEBHOOK_SECRET: secret do
        allow_any_instance_of(Svix::Webhook).to receive(:verify).and_raise(Svix::WebhookVerificationError)

        post '/webhooks/resend/events', params: payload, headers: headers.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
