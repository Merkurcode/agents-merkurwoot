require 'rails_helper'

RSpec.describe Api::V1::Accounts::InboxReengagementTemplatesController, type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:whatsapp_channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
  end
  let(:whatsapp_inbox) { create(:inbox, channel: whatsapp_channel, account: account) }
  let(:web_widget_inbox) { create(:inbox, account: account) }
  let(:mock_service) { instance_double(Whatsapp::ReengagementTemplateService) }

  before do
    create(:inbox_member, user: agent, inbox: whatsapp_inbox)
    allow(Whatsapp::ReengagementTemplateService).to receive(:new).and_return(mock_service)
  end

  describe 'GET /api/v1/accounts/{account.id}/inboxes/{inbox.id}/reengagement_template' do
    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/reengagement_template"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when not a WhatsApp channel' do
      it 'returns bad request' do
        get "/api/v1/accounts/#{account.id}/inboxes/#{web_widget_inbox.id}/reengagement_template",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body['error']).to eq('Reengagement template operations only available for WhatsApp channels')
      end
    end

    context 'when a WhatsApp channel' do
      it 'returns template_exists: false when no config' do
        get "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/reengagement_template",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['template_exists']).to be false
      end

      it 'returns template status when template exists' do
        whatsapp_inbox.update!(reengagement_config: { 'template' => { 'name' => 'proactive_reengagement_40' } })

        allow(mock_service).to receive(:get_template_status)
          .with('proactive_reengagement_40')
          .and_return({ success: true, template: { id: '999', status: 'APPROVED' } })

        get "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/reengagement_template",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        body = response.parsed_body
        expect(body['template_exists']).to be true
        expect(body['status']).to eq('APPROVED')
        expect(body['template_name']).to eq('proactive_reengagement_40')
      end

      it 'returns not found when template does not exist in Meta' do
        whatsapp_inbox.update!(reengagement_config: { 'template' => { 'name' => 'proactive_reengagement_40' } })

        allow(mock_service).to receive(:get_template_status)
          .and_return({ success: false, error: 'Template not found' })

        get "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/reengagement_template",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['template_exists']).to be false
      end

      it 'returns internal server error on service exception' do
        whatsapp_inbox.update!(reengagement_config: { 'template' => { 'name' => 'proactive_reengagement_40' } })

        allow(mock_service).to receive(:get_template_status).and_raise(StandardError, 'API timeout')

        get "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/reengagement_template",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/inboxes/{inbox.id}/reengagement_template' do
    let(:valid_params) do
      {
        template: {
          message: 'Hola {{1}}, ha pasado tiempo. ¿En qué podemos ayudarte?',
          language: 'es_MX'
        }
      }
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/reengagement_template",
             params: valid_params,
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when not a WhatsApp channel' do
      it 'returns bad request' do
        post "/api/v1/accounts/#{account.id}/inboxes/#{web_widget_inbox.id}/reengagement_template",
             headers: admin.create_new_auth_token,
             params: valid_params,
             as: :json

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when a WhatsApp channel' do
      it 'returns error when message is missing' do
        post "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/reengagement_template",
             headers: admin.create_new_auth_token,
             params: { template: { language: 'es_MX' } },
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('Message is required')
      end

      it 'returns error when template params are missing' do
        post "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/reengagement_template",
             headers: admin.create_new_auth_token,
             params: {},
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('Template parameters are required')
      end

      it 'creates template successfully' do
        allow(mock_service).to receive(:get_template_status).and_return({ success: false })
        allow(mock_service).to receive(:create_template).and_return({
                                                                      success: true,
                                                                      template_name: "proactive_reengagement_#{whatsapp_inbox.id}",
                                                                      template_id: '112233',
                                                                      language: 'es_MX'
                                                                    })

        post "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/reengagement_template",
             headers: admin.create_new_auth_token,
             params: valid_params,
             as: :json

        expect(response).to have_http_status(:created)
        body = response.parsed_body
        expect(body['template']['name']).to eq("proactive_reengagement_#{whatsapp_inbox.id}")
        expect(body['template']['status']).to eq('PENDING')
        expect(body['template']['language']).to eq('es_MX')
      end

      it 'deletes existing template before creating new one' do
        whatsapp_inbox.update!(reengagement_config: { 'template' => { 'name' => 'proactive_reengagement_40' } })

        allow(mock_service).to receive(:get_template_status)
          .with('proactive_reengagement_40')
          .and_return({ success: true, template: { id: '111' } })
        expect(mock_service).to receive(:delete_template).with('proactive_reengagement_40').and_return({ success: true })
        expect(mock_service).to receive(:create_template).and_return({
                                                                       success: true,
                                                                       template_name: "proactive_reengagement_#{whatsapp_inbox.id}",
                                                                       template_id: '222'
                                                                     })

        post "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/reengagement_template",
             headers: admin.create_new_auth_token,
             params: valid_params,
             as: :json

        expect(response).to have_http_status(:created)
      end

      it 'handles WhatsApp API errors with user-friendly messages' do
        whatsapp_error = { 'error' => { 'code' => 100, 'error_user_msg' => 'Invalid template content' } }

        allow(mock_service).to receive(:get_template_status).and_return({ success: false })
        allow(mock_service).to receive(:create_template).and_return({
                                                                      success: false,
                                                                      error: 'Template creation failed',
                                                                      response_body: whatsapp_error.to_json
                                                                    })

        post "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/reengagement_template",
             headers: admin.create_new_auth_token,
             params: valid_params,
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('Invalid template content')
      end

      it 'returns unauthorized when agent is not assigned to inbox' do
        other_agent = create(:user, account: account, role: :agent)

        post "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/reengagement_template",
             headers: other_agent.create_new_auth_token,
             params: valid_params,
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
