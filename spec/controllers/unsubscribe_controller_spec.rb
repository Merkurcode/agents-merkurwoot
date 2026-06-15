require 'rails_helper'

RSpec.describe 'UnsubscribeController', type: :request do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account, email: 'lead@example.com') }
  let(:valid_token) do
    ResendComplianceHeaders.generate_unsubscribe_token(contact_id: contact.id, account_id: account.id)
  end

  describe 'GET /unsubscribe' do
    context 'with a valid token' do
      it 'marks the contact as opted out and returns 200' do
        get '/unsubscribe', params: { token: valid_token }

        expect(response).to have_http_status(:ok)
        expect(contact.reload.custom_attributes['email_opted_out']).to be(true)
        expect(contact.custom_attributes['email_opted_out_at']).to be_present
      end
    end

    context 'with an invalid token' do
      it 'returns 404 and does not opt out' do
        get '/unsubscribe', params: { token: 'invalid' }

        expect(response).to have_http_status(:not_found)
        expect(contact.reload.custom_attributes['email_opted_out']).to be_nil
      end
    end
  end

  describe 'POST /unsubscribe (one-click)' do
    it 'marks the contact as opted out and returns 200' do
      post '/unsubscribe', params: { token: valid_token }

      expect(response).to have_http_status(:ok)
      expect(contact.reload.custom_attributes['email_opted_out']).to be(true)
    end

    it 'returns 404 for invalid token' do
      post '/unsubscribe', params: { token: 'invalid' }
      expect(response).to have_http_status(:not_found)
    end
  end
end
