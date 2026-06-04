# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Appointments#available_slots', type: :request do
  let(:account)      { create(:account) }
  let(:agent_user)   { create(:user, account: account, role: :agent) }
  let(:account_user) { agent_user.account_users.find_by(account: account) }

  before do
    create(:working_hour, workable: account_user, day_of_week: 1,
                          open_hour: 9, open_minutes: 0,
                          close_hour: 17, close_minutes: 0)
  end

  def post_slots(params)
    post available_slots_api_v1_account_appointments_path(account_id: account.id),
         headers: { api_access_token: agent_user.access_token.token },
         params: params, as: :json
  end

  describe 'POST /api/v1/accounts/:account_id/appointments/available_slots' do
    context 'con parámetros válidos' do
      it 'retorna 200 con estructura agents y by_datetime' do
        post_slots(owner_ids: [agent_user.id], start_date: '2026-06-08', end_date: '2026-06-08')

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body['agents']).to be_a(Hash)
        expect(body['by_datetime']).to be_a(Hash)
      end

      it 'incluye slots del lunes 09:00–16:30 (30 min)' do
        post_slots(owner_ids: [agent_user.id], start_date: '2026-06-08', end_date: '2026-06-08',
                   slot_duration_minutes: 30)

        body = response.parsed_body
        agent_key = agent_user.id.to_s
        slots = body['agents'][agent_key]['available_slots']['2026-06-08']

        expect(slots.first).to match(/^2026-06-08T09:00:00/)
        expect(slots.last).to match(/^2026-06-08T16:30:00/)
        expect(slots.map { _1.slice(0, 19) }).not_to include('2026-06-08T17:00:00')
      end
    end

    context 'con owner_ids vacío' do
      it 'retorna 422' do
        post_slots(owner_ids: [], start_date: '2026-06-08', end_date: '2026-06-08')

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('owner_ids is required')
      end
    end

    context 'con más de 20 owner_ids' do
      it 'retorna 422' do
        post_slots(owner_ids: (1..21).to_a, start_date: '2026-06-08', end_date: '2026-06-08')

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('Maximum 20 agents per request')
      end
    end

    context 'con rango mayor a 14 días' do
      it 'retorna 422' do
        post_slots(owner_ids: [agent_user.id], start_date: '2026-06-01', end_date: '2026-06-16')

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('Maximum date range is 14 days')
      end
    end

    context 'con fecha inválida' do
      it 'retorna 422' do
        post_slots(owner_ids: [agent_user.id], start_date: 'not-a-date', end_date: '2026-06-08')

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'sin autenticación' do
      it 'retorna 401' do
        post available_slots_api_v1_account_appointments_path(account_id: account.id),
             params: { owner_ids: [agent_user.id], start_date: '2026-06-08', end_date: '2026-06-08' },
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
