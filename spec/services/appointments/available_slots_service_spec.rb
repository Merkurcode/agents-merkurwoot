# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Appointments::AvailableSlotsService do
  let(:account) { create(:account) }
  let(:user)    { create(:user, account: account) }
  let(:account_user) do
    au = user.account_users.find_by!(account: account)
    au.update!(timezone: 'UTC')
    au
  end

  # AccountUser auto-recibe: Lun–Vie 9-17, Sáb-Dom cerrados
  # Lunes 2026-06-08, Domingo 2026-06-07
  let(:monday)  { Date.new(2026, 6, 8) }
  let(:sunday)  { Date.new(2026, 6, 7) }

  # Acceder a account_user para que se configure la timezone antes de llamar al servicio
  before { account_user }

  def call(owner_ids: [user.id], start_date: monday, end_date: monday, slot_duration_minutes: 30)
    described_class.new(
      account:               account,
      owner_ids:             owner_ids,
      start_date:            start_date,
      end_date:              end_date,
      slot_duration_minutes: slot_duration_minutes
    ).call
  end

  describe 'validaciones de límites' do
    it 'lanza ArgumentError si owner_ids está vacío' do
      expect { call(owner_ids: []) }.to raise_error(ArgumentError, 'owner_ids is required')
    end

    it 'lanza ArgumentError con más de 20 owner_ids' do
      expect { call(owner_ids: (1..21).to_a) }.to raise_error(ArgumentError, 'Maximum 20 agents per request')
    end

    it 'lanza ArgumentError con rango mayor a 14 días' do
      expect { call(start_date: monday, end_date: monday + 14) }.to raise_error(ArgumentError, 'Maximum date range is 14 days')
    end
  end

  describe 'generación de slots' do
    it 'retorna slots de 30 minutos entre las 9:00 y las 16:30' do
      result = call
      slots = result[:agents][user.id][:available_slots][monday.iso8601]

      expect(slots).to include('2026-06-08T09:00:00Z')
      expect(slots).to include('2026-06-08T16:30:00Z')
      expect(slots).not_to include('2026-06-08T17:00:00Z')
    end

    it 'retorna slots de 60 minutos correctamente' do
      result = call(slot_duration_minutes: 60)
      slots = result[:agents][user.id][:available_slots][monday.iso8601]

      expect(slots).to include('2026-06-08T09:00:00Z')
      expect(slots).to include('2026-06-08T16:00:00Z')
      expect(slots).not_to include('2026-06-08T16:30:00Z')
    end

    it 'excluye slots dentro de un schedule_block' do
      create(:schedule_block, account_user: account_user, day_of_week: 1,
                              start_hour: 12, start_minutes: 0,
                              end_hour: 13, end_minutes: 0)

      result = call
      slots = result[:agents][user.id][:available_slots][monday.iso8601]

      expect(slots).not_to include('2026-06-08T12:00:00Z')
      expect(slots).not_to include('2026-06-08T12:30:00Z')
      expect(slots).to include('2026-06-08T13:00:00Z')
      expect(slots).to include('2026-06-08T11:30:00Z')
    end

    it 'excluye slots que solapan citas existentes' do
      contact = create(:contact, account: account)
      Appointment.create!(
        account:          account,
        contact:          contact,
        owner_id:         user.id,
        scheduled_at:     Time.zone.parse('2026-06-08 10:00:00 UTC'),
        appointment_type: 'phone_call',
        phone_number:     '+1234567890',
        status:           :scheduled
      )

      result = call
      slots = result[:agents][user.id][:available_slots][monday.iso8601]

      expect(slots).not_to include('2026-06-08T10:00:00Z')
      expect(slots).to include('2026-06-08T09:30:00Z')
      expect(slots).to include('2026-06-08T10:30:00Z')
    end

    it 'no devuelve slots para días cerrados (domingo cerrado por defecto)' do
      result = call(start_date: sunday, end_date: sunday)
      agent_data = result[:agents][user.id]

      expect(agent_data[:available_slots]).not_to have_key(sunday.iso8601)
    end

    it 'filtra silenciosamente owner_ids de otras cuentas' do
      other_user = create(:user)
      result = call(owner_ids: [user.id, other_user.id])

      expect(result[:agents]).to have_key(user.id)
      expect(result[:agents]).not_to have_key(other_user.id)
    end
  end

  describe 'estructura de respuesta' do
    it 'incluye name y timezone del agente' do
      result = call
      agent_data = result[:agents][user.id]

      expect(agent_data[:name]).to eq(user.name)
      expect(agent_data[:timezone]).to eq('UTC')
    end

    it 'popula by_datetime con los owner_ids' do
      result = call
      slot_utc = '2026-06-08T09:00:00Z'

      expect(result[:by_datetime][slot_utc]).to include(user.id)
    end
  end
end
