# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Lead Follow-up Sequences API', type: :request do
  let(:account) { create(:account) }
  let(:whatsapp_channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
  let(:whatsapp_inbox) { create(:inbox, channel: whatsapp_channel, account: account) }

  describe 'GET /api/v1/accounts/{account.id}/copilot_sequences' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/copilot_sequences"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:administrator) { create(:user, account: account, role: :administrator) }
      let!(:sequence) { create(:lead_follow_up_sequence, account: account, inbox: whatsapp_inbox) }

      it 'returns unauthorized for agents' do
        get "/api/v1/accounts/#{account.id}/copilot_sequences",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns all sequences to administrators' do
        get "/api/v1/accounts/#{account.id}/copilot_sequences",
            headers: administrator.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body, symbolize_names: true)
        expect(body.first[:id]).to eq(sequence.id)
      end

      it 'filters by inbox_id when provided' do
        other_inbox = create(:inbox, channel: create(:channel_whatsapp, account: account,
                                                                        sync_templates: false,
                                                                        validate_provider_config: false),
                                     account: account)
        other_sequence = create(:lead_follow_up_sequence, account: account, inbox: other_inbox)

        get "/api/v1/accounts/#{account.id}/copilot_sequences?inbox_id=#{whatsapp_inbox.id}",
            headers: administrator.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body, symbolize_names: true)
        expect(body.length).to eq(1)
        expect(body.first[:id]).to eq(sequence.id)
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/copilot_sequences/:id' do
    let(:sequence) { create(:lead_follow_up_sequence, account: account, inbox: whatsapp_inbox) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/copilot_sequences/#{sequence.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:administrator) { create(:user, account: account, role: :administrator) }

      it 'returns unauthorized for agents' do
        get "/api/v1/accounts/#{account.id}/copilot_sequences/#{sequence.id}",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'shows the sequence for administrators' do
        get "/api/v1/accounts/#{account.id}/copilot_sequences/#{sequence.id}",
            headers: administrator.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body, symbolize_names: true)[:id]).to eq(sequence.id)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/copilot_sequences' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/copilot_sequences"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:administrator) { create(:user, account: account, role: :administrator) }
      let(:valid_params) do
        {
          lead_follow_up_sequence: {
            name: 'Test Sequence',
            description: 'Test description',
            inbox_id: whatsapp_inbox.id,
            active: true,
            steps: [
              {
                id: 'step_1',
                type: 'wait',
                enabled: true,
                config: {
                  delay_value: 2,
                  delay_type: 'hours'
                }
              }
            ],
            settings: {
              stop_on_contact_reply: true
            }
          }
        }
      end

      it 'creates a new sequence' do
        expect do
          post "/api/v1/accounts/#{account.id}/copilot_sequences",
               headers: administrator.create_new_auth_token,
               params: valid_params,
               as: :json
        end.to change(LeadFollowUpSequence, :count).by(1)

        expect(response).to have_http_status(:created)
      end

      it 'returns validation errors for invalid params' do
        invalid_params = {
          lead_follow_up_sequence: {
            name: '',
            inbox_id: whatsapp_inbox.id
          }
        }

        post "/api/v1/accounts/#{account.id}/copilot_sequences",
             headers: administrator.create_new_auth_token,
             params: invalid_params,
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body, symbolize_names: true)
        expect(body[:errors]).to be_present
      end
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/copilot_sequences/:id' do
    let(:sequence) { create(:lead_follow_up_sequence, account: account, inbox: whatsapp_inbox) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        patch "/api/v1/accounts/#{account.id}/copilot_sequences/#{sequence.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:administrator) { create(:user, account: account, role: :administrator) }
      let(:update_params) do
        {
          lead_follow_up_sequence: {
            name: 'Updated Name'
          }
        }
      end

      it 'updates the sequence' do
        patch "/api/v1/accounts/#{account.id}/copilot_sequences/#{sequence.id}",
              headers: administrator.create_new_auth_token,
              params: update_params,
              as: :json

        expect(response).to have_http_status(:success)
        expect(sequence.reload.name).to eq('Updated Name')
      end
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/copilot_sequences/:id' do
    let!(:sequence) { create(:lead_follow_up_sequence, account: account, inbox: whatsapp_inbox, active: true) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        delete "/api/v1/accounts/#{account.id}/copilot_sequences/#{sequence.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:administrator) { create(:user, account: account, role: :administrator) }

      it 'deactivates and deletes the sequence' do
        delete "/api/v1/accounts/#{account.id}/copilot_sequences/#{sequence.id}",
               headers: administrator.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:no_content)
        expect(LeadFollowUpSequence.exists?(sequence.id)).to be false
      end

      it 'deactivates sequence before deletion if active' do
        conversation = create(:conversation, account: account, inbox: whatsapp_inbox)
        create(:conversation_follow_up,
               conversation: conversation,
               lead_follow_up_sequence: sequence,
               status: 'active')

        expect_any_instance_of(LeadFollowUpSequence).to receive(:deactivate!).and_call_original

        delete "/api/v1/accounts/#{account.id}/copilot_sequences/#{sequence.id}",
               headers: administrator.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:no_content)
        expect(LeadFollowUpSequence.exists?(sequence.id)).to be false
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/copilot_sequences/:id/activate' do
    let(:sequence) { create(:lead_follow_up_sequence, account: account, inbox: whatsapp_inbox, active: false) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/copilot_sequences/#{sequence.id}/activate"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:administrator) { create(:user, account: account, role: :administrator) }

      it 'activates the sequence' do
        post "/api/v1/accounts/#{account.id}/copilot_sequences/#{sequence.id}/activate",
             headers: administrator.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(sequence.reload.active).to be true
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/copilot_sequences/:id/deactivate' do
    let(:sequence) { create(:lead_follow_up_sequence, account: account, inbox: whatsapp_inbox, active: true) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/copilot_sequences/#{sequence.id}/deactivate"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:administrator) { create(:user, account: account, role: :administrator) }

      it 'deactivates the sequence' do
        post "/api/v1/accounts/#{account.id}/copilot_sequences/#{sequence.id}/deactivate",
             headers: administrator.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(sequence.reload.active).to be false
      end

      it 'cancels active follow-ups' do
        conversation = create(:conversation, account: account, inbox: whatsapp_inbox)
        follow_up = create(:conversation_follow_up,
                           conversation: conversation,
                           lead_follow_up_sequence: sequence,
                           status: 'active')

        post "/api/v1/accounts/#{account.id}/copilot_sequences/#{sequence.id}/deactivate",
             headers: administrator.create_new_auth_token,
             as: :json

        expect(follow_up.reload.status).to eq('cancelled')
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/copilot_sequences/:id/enrollments/:enrollment_id/result' do
    let(:sequence) do
      create(:lead_follow_up_sequence, account: account, inbox: whatsapp_inbox,
                                       result_schema: [
                                         { 'key' => 'outcome', 'label' => 'Outcome', 'type' => 'select',
                                           'required' => true,
                                           'options' => [{ 'label' => 'Converted', 'value' => 'converted' }] }
                                       ])
    end
    let(:conversation) { create(:conversation, account: account, inbox: whatsapp_inbox) }
    let(:enrollment) { create(:sequence_enrollment, :completed, conversation: conversation, lead_follow_up_sequence: sequence) }

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/copilot_sequences/#{sequence.id}/enrollments/#{enrollment.id}/result"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as administrator' do
      let(:administrator) { create(:user, account: account, role: :administrator) }

      it 'stores the result values' do
        post "/api/v1/accounts/#{account.id}/copilot_sequences/#{sequence.id}/enrollments/#{enrollment.id}/result",
             headers: administrator.create_new_auth_token,
             params: { values: { outcome: 'converted' } },
             as: :json

        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body, symbolize_names: true)
        expect(body[:result][:outcome]).to eq('converted')
        expect(body[:result_complete]).to be true
      end

      it 'returns not_found for a non-existent enrollment' do
        post "/api/v1/accounts/#{account.id}/copilot_sequences/#{sequence.id}/enrollments/0/result",
             headers: administrator.create_new_auth_token,
             params: { values: { outcome: 'converted' } },
             as: :json

        expect(response).to have_http_status(:not_found)
      end

      it 'sets result_captured_by to human' do
        post "/api/v1/accounts/#{account.id}/copilot_sequences/#{sequence.id}/enrollments/#{enrollment.id}/result",
             headers: administrator.create_new_auth_token,
             params: { values: { outcome: 'converted' } },
             as: :json

        expect(enrollment.reload.result_captured_by).to eq('human')
      end
    end

    context 'when authenticated as agent_bot' do
      let(:agent_bot) { create(:agent_bot, account: account) }

      before { create(:agent_bot_inbox, inbox: whatsapp_inbox, agent_bot: agent_bot) }

      it 'stores the result and marks captured_by as agent_bot' do
        post "/api/v1/accounts/#{account.id}/copilot_sequences/#{sequence.id}/enrollments/#{enrollment.id}/result",
             headers: { api_access_token: agent_bot.access_token.token },
             params: { values: { outcome: 'converted' } },
             as: :json

        expect(response).to have_http_status(:success)
        expect(enrollment.reload.result_captured_by).to eq('agent_bot')
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/copilot_sequences/:id/enrollments/:enrollment_id/cancel' do
    let(:sequence) { create(:lead_follow_up_sequence, account: account, inbox: whatsapp_inbox) }
    let(:conversation) { create(:conversation, account: account, inbox: whatsapp_inbox) }
    let(:enrollment) { create(:sequence_enrollment, conversation: conversation, lead_follow_up_sequence: sequence) }

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/copilot_sequences/#{sequence.id}/enrollments/#{enrollment.id}/cancel"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as administrator' do
      let(:administrator) { create(:user, account: account, role: :administrator) }

      it 'cancels the enrollment' do
        post "/api/v1/accounts/#{account.id}/copilot_sequences/#{sequence.id}/enrollments/#{enrollment.id}/cancel",
             headers: administrator.create_new_auth_token,
             params: { reason: 'bad_experience' },
             as: :json

        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body, symbolize_names: true)
        expect(body[:status]).to eq('cancelled')
        expect(body[:reason]).to eq('bad_experience')
      end

      it 'rejects cancelling an already-completed enrollment' do
        enrollment.update!(status: 'completed', completed_at: Time.current)

        post "/api/v1/accounts/#{account.id}/copilot_sequences/#{sequence.id}/enrollments/#{enrollment.id}/cancel",
             headers: administrator.create_new_auth_token,
             params: { reason: 'test' },
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'stores result values when provided alongside cancellation' do
        sequence.update!(result_schema: [
                           { 'key' => 'reason', 'label' => 'Reason', 'type' => 'text', 'required' => false }
                         ])

        post "/api/v1/accounts/#{account.id}/copilot_sequences/#{sequence.id}/enrollments/#{enrollment.id}/cancel",
             headers: administrator.create_new_auth_token,
             params: { reason: 'bad_experience', values: { reason: 'Too pushy' } },
             as: :json

        expect(response).to have_http_status(:success)
        expect(enrollment.reload.result_values.count).to eq(1)
      end
    end

    context 'when authenticated as agent_bot' do
      let(:agent_bot) { create(:agent_bot, account: account) }

      before { create(:agent_bot_inbox, inbox: whatsapp_inbox, agent_bot: agent_bot) }

      it 'cancels the enrollment and sets captured_by to agent_bot' do
        post "/api/v1/accounts/#{account.id}/copilot_sequences/#{sequence.id}/enrollments/#{enrollment.id}/cancel",
             headers: { api_access_token: agent_bot.access_token.token },
             params: { reason: 'bad_experience' },
             as: :json

        expect(response).to have_http_status(:success)
        expect(enrollment.reload.status).to eq('cancelled')
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/copilot_sequences/:id/result_indicators' do
    let(:sequence) do
      create(:lead_follow_up_sequence, account: account, inbox: whatsapp_inbox,
                                       result_schema: [
                                         { 'key' => 'outcome', 'label' => 'Outcome', 'type' => 'select',
                                           'required' => true,
                                           'options' => [{ 'label' => 'Converted', 'value' => 'converted' }] }
                                       ])
    end
    let(:conversation) { create(:conversation, account: account, inbox: whatsapp_inbox) }
    let(:enrollment) { create(:sequence_enrollment, :completed, conversation: conversation, lead_follow_up_sequence: sequence) }

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/copilot_sequences/#{sequence.id}/result_indicators"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as administrator' do
      let(:administrator) { create(:user, account: account, role: :administrator) }

      it 'returns empty indicators when no result_schema' do
        sequence.update!(result_schema: [])

        get "/api/v1/accounts/#{account.id}/copilot_sequences/#{sequence.id}/result_indicators",
            headers: administrator.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body, symbolize_names: true)
        expect(body[:indicators]).to eq({})
      end

      it 'returns counts grouped by field and value' do
        create(:enrollment_result_value,
               sequence_enrollment: enrollment,
               lead_follow_up_sequence: sequence,
               field_key: 'outcome',
               value: 'converted')

        get "/api/v1/accounts/#{account.id}/copilot_sequences/#{sequence.id}/result_indicators",
            headers: administrator.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body, symbolize_names: true)
        expect(body[:indicators][:outcome][:counts][:converted]).to eq(1)
        expect(body[:indicators][:outcome][:label]).to eq('Outcome')
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/copilot_sequences/:id/enrolled_conversations' do
    let(:sequence) { create(:lead_follow_up_sequence, account: account, inbox: whatsapp_inbox) }
    let(:url) { "/api/v1/accounts/#{account.id}/copilot_sequences/#{sequence.id}/enrolled_conversations" }

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get url
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as agent' do
      let(:agent) { create(:user, account: account, role: :agent) }

      it 'returns unauthorized' do
        get url, headers: agent.create_new_auth_token, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as administrator' do
      let(:administrator) { create(:user, account: account, role: :administrator) }

      it 'returns success with empty list when no enrollments exist' do
        get url, headers: administrator.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body, symbolize_names: true)
        expect(body[:enrolled_conversations]).to eq([])
        expect(body[:total_count]).to eq(0)
        expect(body[:total_pages]).to eq(0)
      end

      context 'with enrollments' do
        let(:conversation) { create(:conversation, account: account, inbox: whatsapp_inbox) }
        let!(:enrollment) { create(:sequence_enrollment, conversation: conversation, lead_follow_up_sequence: sequence) }

        it 'returns the enrollment with the expected fields' do
          get url, headers: administrator.create_new_auth_token, as: :json

          expect(response).to have_http_status(:success)
          body = JSON.parse(response.body, symbolize_names: true)
          item = body[:enrolled_conversations].first

          expect(item[:id]).to eq(enrollment.id)
          expect(item[:enrollment_id]).to eq(enrollment.id)
          expect(item[:display_id]).to eq(conversation.display_id)
          expect(item[:status]).to eq('active')
          expect(item[:contact][:id]).to eq(conversation.contact.id)
          expect(item[:contact][:name]).to eq(conversation.contact.name)
        end

        it 'returns correct pagination metadata' do
          get url, headers: administrator.create_new_auth_token, as: :json

          body = JSON.parse(response.body, symbolize_names: true)
          expect(body[:total_count]).to eq(1)
          expect(body[:page]).to eq(1)
          expect(body[:per_page]).to eq(50)
          expect(body[:total_pages]).to eq(1)
        end

        it 'returns status_counts for all statuses' do
          completed_conv = create(:conversation, account: account, inbox: whatsapp_inbox)
          create(:sequence_enrollment, :completed, conversation: completed_conv, lead_follow_up_sequence: sequence)

          get url, headers: administrator.create_new_auth_token, as: :json

          body = JSON.parse(response.body, symbolize_names: true)
          expect(body[:status_counts][:active]).to eq(1)
          expect(body[:status_counts][:completed]).to eq(1)
        end
      end

      context 'with pagination' do
        before do
          stub_const('Api::V1::Accounts::LeadFollowUpSequencesController::DEFAULT_PER_PAGE', 2) if
            defined?(Api::V1::Accounts::LeadFollowUpSequencesController::DEFAULT_PER_PAGE)

          3.times do
            conv = create(:conversation, account: account, inbox: whatsapp_inbox)
            create(:sequence_enrollment, conversation: conv, lead_follow_up_sequence: sequence)
          end
        end

        it 'returns only the requested page window' do
          get url, params: { page: 1, per_page: 2 }, headers: administrator.create_new_auth_token, as: :json

          body = JSON.parse(response.body, symbolize_names: true)
          expect(body[:enrolled_conversations].length).to eq(2)
          expect(body[:total_count]).to eq(3)
          expect(body[:total_pages]).to eq(2)
          expect(body[:page]).to eq(1)
          expect(body[:per_page]).to eq(2)
        end

        it 'returns the second page correctly' do
          get url, params: { page: 2, per_page: 2 }, headers: administrator.create_new_auth_token, as: :json

          body = JSON.parse(response.body, symbolize_names: true)
          expect(body[:enrolled_conversations].length).to eq(1)
          expect(body[:page]).to eq(2)
        end

        it 'caps per_page at 100' do
          get url, params: { per_page: 500 }, headers: administrator.create_new_auth_token, as: :json

          body = JSON.parse(response.body, symbolize_names: true)
          expect(body[:per_page]).to eq(100)
        end
      end

      context 'with status filter' do
        let(:conv_active) { create(:conversation, account: account, inbox: whatsapp_inbox) }
        let(:conv_completed) { create(:conversation, account: account, inbox: whatsapp_inbox) }
        let!(:active_enrollment) { create(:sequence_enrollment, conversation: conv_active, lead_follow_up_sequence: sequence) }
        let!(:completed_enrollment) do
          create(:sequence_enrollment, :completed, conversation: conv_completed, lead_follow_up_sequence: sequence)
        end

        it 'returns only active enrollments when filtered by status=active' do
          get url, params: { status: 'active' }, headers: administrator.create_new_auth_token, as: :json

          body = JSON.parse(response.body, symbolize_names: true)
          expect(body[:enrolled_conversations].length).to eq(1)
          expect(body[:enrolled_conversations].first[:id]).to eq(active_enrollment.id)
          expect(body[:total_count]).to eq(1)
        end

        it 'returns only completed enrollments when filtered by status=completed' do
          get url, params: { status: 'completed' }, headers: administrator.create_new_auth_token, as: :json

          body = JSON.parse(response.body, symbolize_names: true)
          expect(body[:enrolled_conversations].length).to eq(1)
          expect(body[:enrolled_conversations].first[:id]).to eq(completed_enrollment.id)
        end

        it 'returns all enrollments when no status filter is applied' do
          get url, headers: administrator.create_new_auth_token, as: :json

          body = JSON.parse(response.body, symbolize_names: true)
          expect(body[:total_count]).to eq(2)
        end

        it 'always reflects all statuses in status_counts regardless of filter' do
          get url, params: { status: 'active' }, headers: administrator.create_new_auth_token, as: :json

          body = JSON.parse(response.body, symbolize_names: true)
          expect(body[:status_counts][:active]).to eq(1)
          expect(body[:status_counts][:completed]).to eq(1)
        end
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/copilot_sequences/available_templates' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/copilot_sequences/available_templates?inbox_id=#{whatsapp_inbox.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:administrator) { create(:user, account: account, role: :administrator) }

      it 'returns available templates for WhatsApp inbox' do
        allow_any_instance_of(Channel::Whatsapp).to receive(:message_templates).and_return([
                                                                                              {
                                                                                                'name' => 'template_1',
                                                                                                'language' => 'en',
                                                                                                'status' => 'APPROVED',
                                                                                                'category' => 'MARKETING',
                                                                                                'components' => []
                                                                                              }
                                                                                            ])

        get "/api/v1/accounts/#{account.id}/copilot_sequences/available_templates?inbox_id=#{whatsapp_inbox.id}",
            headers: administrator.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body, symbolize_names: true)
        expect(body[:templates]).to be_present
        expect(body[:templates].first[:name]).to eq('template_1')
      end

      it 'returns error for non-WhatsApp inbox' do
        web_inbox = create(:inbox, channel: create(:channel_widget, account: account), account: account)

        get "/api/v1/accounts/#{account.id}/copilot_sequences/available_templates?inbox_id=#{web_inbox.id}",
            headers: administrator.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body, symbolize_names: true)
        expect(body[:error]).to eq('Inbox must be WhatsApp')
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/copilot_sequences/preview_eligible_contacts' do
    let(:administrator) { create(:user, account: account, role: :administrator) }
    let(:url) { "/api/v1/accounts/#{account.id}/copilot_sequences/preview_eligible_contacts" }

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post url
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as administrator' do
      before { create(:contact, account: account, phone_number: '+521234567890') }

      it 'returns total_count and contacts with no filters' do
        post url,
             params: { source_config: {} },
             headers: administrator.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body, symbolize_names: true)
        expect(body[:total_count]).to eq(1)
        expect(body[:contacts].length).to eq(1)
        expect(body[:contacts].first[:phone_number]).to eq('+521234567890')
      end

      it 'filters by require_phone' do
        create(:contact, account: account, phone_number: nil, email: 'nophone@example.com')

        post url,
             params: { source_config: { require_phone: true } },
             headers: administrator.create_new_auth_token,
             as: :json

        body = JSON.parse(response.body, symbolize_names: true)
        expect(body[:total_count]).to eq(1)
      end

      it 'filters by require_email' do
        create(:contact, account: account, email: 'has@email.com')

        post url,
             params: { source_config: { require_email: true } },
             headers: administrator.create_new_auth_token,
             as: :json

        body = JSON.parse(response.body, symbolize_names: true)
        expect(body[:total_count]).to eq(1)
        expect(body[:contacts].first[:email]).to eq('has@email.com')
      end

      it 'filters by created_at newer_than' do
        create(:contact, account: account, created_at: 60.days.ago)

        post url,
             params: { source_config: { created_at_filter: { enabled: true, operator: 'newer_than', value: 30 } } },
             headers: administrator.create_new_auth_token,
             as: :json

        body = JSON.parse(response.body, symbolize_names: true)
        expect(body[:total_count]).to eq(1)
      end

      it 'filters by custom_attribute equal_to' do
        create(:contact, account: account, custom_attributes: { 'plan' => 'pro' })

        post url,
             params: {
               source_config: {
                 custom_attribute_filters: [{ attribute_key: 'plan', operator: 'equal_to', value: 'pro' }]
               }
             },
             headers: administrator.create_new_auth_token,
             as: :json

        body = JSON.parse(response.body, symbolize_names: true)
        expect(body[:total_count]).to eq(1)
      end

      it 'returns contacts with labels included' do
        contact = create(:contact, account: account, phone_number: '+521111111111')
        contact.update(label_list: ['vip'])

        post url,
             params: { source_config: {} },
             headers: administrator.create_new_auth_token,
             as: :json

        body = JSON.parse(response.body, symbolize_names: true)
        expect(body[:contacts].first[:labels]).to include('vip')
      end

      it 'returns capped: false when count is below the cap' do
        post url,
             params: { source_config: {} },
             headers: administrator.create_new_auth_token,
             as: :json

        body = JSON.parse(response.body, symbolize_names: true)
        expect(body[:capped]).to be false
      end

      it 'returns capped: true and total_count equal to the cap when results exceed the cap' do
        # Lower the cap constant so we can test with a small number of real DB records
        stub_const('Api::V1::Accounts::LeadFollowUpSequencesController::PREVIEW_CONTACTS_CAP', 1)

        # before block already created 1 contact; create one more to exceed the cap of 1
        create(:contact, account: account, phone_number: '+529999999999')

        post url,
             params: { source_config: {} },
             headers: administrator.create_new_auth_token,
             as: :json

        body = JSON.parse(response.body, symbolize_names: true)
        expect(body[:capped]).to be true
        expect(body[:total_count]).to eq(1) # equals the stubbed cap
      end

      it 'applies OR logic between custom_attribute_filters with logical_operator: or' do
        create(:contact, account: account, custom_attributes: { 'city' => 'CDMX' })
        create(:contact, account: account, custom_attributes: { 'city' => 'GDL' })
        create(:contact, account: account, custom_attributes: { 'city' => 'MTY' })

        post url,
             params: {
               source_config: {
                 custom_attribute_filters: [
                   { attribute_key: 'city', operator: 'equal_to', value: 'CDMX', logical_operator: 'and' },
                   { attribute_key: 'city', operator: 'equal_to', value: 'GDL',  logical_operator: 'or' }
                 ]
               }
             },
             headers: administrator.create_new_auth_token,
             as: :json

        body = JSON.parse(response.body, symbolize_names: true)
        # The 'before' contact has no city attribute and won't match; only CDMX + GDL contacts match
        expect(body[:total_count]).to eq(2)
      end

      it 'applies AND logic between filters within the same OR group' do
        create(:contact, account: account, custom_attributes: { 'plan' => 'pro', 'city' => 'CDMX' })
        create(:contact, account: account, custom_attributes: { 'plan' => 'pro', 'city' => 'GDL' })
        create(:contact, account: account, custom_attributes: { 'plan' => 'free', 'city' => 'CDMX' })

        post url,
             params: {
               source_config: {
                 custom_attribute_filters: [
                   { attribute_key: 'plan', operator: 'equal_to', value: 'pro',  logical_operator: 'and' },
                   { attribute_key: 'city', operator: 'equal_to', value: 'CDMX', logical_operator: 'and' }
                 ]
               }
             },
             headers: administrator.create_new_auth_token,
             as: :json

        body = JSON.parse(response.body, symbolize_names: true)
        # Only the contact with plan=pro AND city=CDMX matches
        expect(body[:total_count]).to eq(1)
      end

      it 'returns correct count for mixed AND/OR groups: (plan=pro AND city=CDMX) OR (city=GDL)' do
        create(:contact, account: account, custom_attributes: { 'plan' => 'pro',  'city' => 'CDMX' }) # group 1 ✓
        create(:contact, account: account, custom_attributes: { 'plan' => 'free', 'city' => 'CDMX' }) # group 1 ✗
        create(:contact, account: account, custom_attributes: { 'plan' => 'free', 'city' => 'GDL' })  # group 2 ✓
        create(:contact, account: account, custom_attributes: { 'plan' => 'pro',  'city' => 'GDL' })  # group 2 ✓

        post url,
             params: {
               source_config: {
                 custom_attribute_filters: [
                   { attribute_key: 'plan', operator: 'equal_to', value: 'pro',  logical_operator: 'and' },
                   { attribute_key: 'city', operator: 'equal_to', value: 'CDMX', logical_operator: 'and' },
                   { attribute_key: 'city', operator: 'equal_to', value: 'GDL',  logical_operator: 'or' }
                 ]
               }
             },
             headers: administrator.create_new_auth_token,
             as: :json

        body = JSON.parse(response.body, symbolize_names: true)
        # 1 (from before) + 1 (pro+CDMX) + 2 (GDL) = but before contact has no custom_attrs, doesn't match
        expect(body[:total_count]).to eq(3)
      end

      it 'treats filters without logical_operator as AND (backward compat)' do
        create(:contact, account: account, custom_attributes: { 'plan' => 'pro',  'city' => 'CDMX' })
        create(:contact, account: account, custom_attributes: { 'plan' => 'pro',  'city' => 'GDL' })
        create(:contact, account: account, custom_attributes: { 'plan' => 'free', 'city' => 'CDMX' })

        post url,
             params: {
               source_config: {
                 # No logical_operator field — old format
                 custom_attribute_filters: [
                   { attribute_key: 'plan', operator: 'equal_to', value: 'pro' },
                   { attribute_key: 'city', operator: 'equal_to', value: 'CDMX' }
                 ]
               }
             },
             headers: administrator.create_new_auth_token,
             as: :json

        body = JSON.parse(response.body, symbolize_names: true)
        expect(body[:total_count]).to eq(1)
      end
    end
  end
end
