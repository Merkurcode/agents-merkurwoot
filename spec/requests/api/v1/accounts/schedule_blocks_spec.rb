# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::ScheduleBlocks', type: :request do
  let(:account)      { create(:account) }
  let(:agent_user)   { create(:user, account: account, role: :agent) }
  let(:account_user) { agent_user.account_users.find_by(account: account) }
  let(:admin_user)   { create(:user, account: account, role: :administrator) }

  let(:valid_params) do
    {
      schedule_block: {
        day_of_week:   1,
        start_hour:    12,
        start_minutes: 0,
        end_hour:      13,
        end_minutes:   0,
        reason:        'Almuerzo'
      }
    }
  end

  describe 'GET /api/v1/accounts/:account_id/agents/:agent_id/schedule_blocks' do
    context 'con token del propio agente' do
      it 'retorna 200 y la lista de bloques' do
        create(:schedule_block, account_user: account_user)

        get api_v1_account_agent_schedule_blocks_path(account_id: account.id, agent_id: agent_user.id),
            headers: { api_access_token: agent_user.access_token.token },
            as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response.length).to eq(1)
      end
    end

    context 'con token de administrador' do
      it 'retorna 200' do
        get api_v1_account_agent_schedule_blocks_path(account_id: account.id, agent_id: agent_user.id),
            headers: { api_access_token: admin_user.access_token.token },
            as: :json

        expect(response).to have_http_status(:ok)
      end
    end

    context 'con token de otro agente' do
      let(:other_agent) { create(:user, account: account, role: :agent) }

      it 'retorna 403' do
        get api_v1_account_agent_schedule_blocks_path(account_id: account.id, agent_id: agent_user.id),
            headers: { api_access_token: other_agent.access_token.token },
            as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'con agente inexistente' do
      it 'retorna 404' do
        get api_v1_account_agent_schedule_blocks_path(account_id: account.id, agent_id: 999_999),
            headers: { api_access_token: admin_user.access_token.token },
            as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /api/v1/accounts/:account_id/agents/:agent_id/schedule_blocks' do
    context 'con parámetros válidos' do
      it 'crea el bloque y retorna 201' do
        post api_v1_account_agent_schedule_blocks_path(account_id: account.id, agent_id: agent_user.id),
             headers: { api_access_token: agent_user.access_token.token },
             params: valid_params, as: :json

        expect(response).to have_http_status(:created)
        expect(json_response['day_of_week']).to eq(1)
        expect(json_response['reason']).to eq('Almuerzo')
      end
    end

    context 'con parámetros inválidos (end antes que start)' do
      it 'retorna 422 con errores' do
        post api_v1_account_agent_schedule_blocks_path(account_id: account.id, agent_id: agent_user.id),
             headers: { api_access_token: agent_user.access_token.token },
             params: { schedule_block: valid_params[:schedule_block].merge(end_hour: 11) },
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).to be_present
      end
    end

    context 'con token de otro agente' do
      let(:other_agent) { create(:user, account: account, role: :agent) }

      it 'retorna 403' do
        post api_v1_account_agent_schedule_blocks_path(account_id: account.id, agent_id: agent_user.id),
             headers: { api_access_token: other_agent.access_token.token },
             params: valid_params, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'PATCH /api/v1/accounts/:account_id/agents/:agent_id/schedule_blocks/:id' do
    let!(:block) { create(:schedule_block, account_user: account_user) }

    it 'actualiza el bloque y retorna 200' do
      patch api_v1_account_agent_schedule_block_path(account_id: account.id, agent_id: agent_user.id, id: block.id),
            headers: { api_access_token: agent_user.access_token.token },
            params: { schedule_block: { reason: 'Reunión de equipo' } },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['reason']).to eq('Reunión de equipo')
    end
  end

  describe 'DELETE /api/v1/accounts/:account_id/agents/:agent_id/schedule_blocks/:id' do
    let!(:block) { create(:schedule_block, account_user: account_user) }

    it 'elimina el bloque y retorna 204' do
      delete api_v1_account_agent_schedule_block_path(account_id: account.id, agent_id: agent_user.id, id: block.id),
             headers: { api_access_token: agent_user.access_token.token },
             as: :json

      expect(response).to have_http_status(:no_content)
      expect(ScheduleBlock.exists?(block.id)).to be false
    end
  end

  def json_response
    response.parsed_body
  end
end
