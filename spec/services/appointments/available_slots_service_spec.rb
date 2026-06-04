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

  # El account de test no tiene business_hours_timezone → fallback 'UTC'
  # Ruby devuelve "+00:00" al usar in_time_zone('UTC').iso8601 (no "Z")
  let(:monday) { Date.new(2026, 6, 8) }
  let(:sunday) { Date.new(2026, 6, 7) }

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

  # Convierte un string UTC "HH:MM" al formato ISO8601 local que el servicio produce
  def slot(date, time)
    Time.zone.parse("#{date} #{time} UTC").in_time_zone('UTC').iso8601
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

      expect(slots).to include(slot('2026-06-08', '09:00:00'))
      expect(slots).to include(slot('2026-06-08', '16:30:00'))
      expect(slots).not_to include(slot('2026-06-08', '17:00:00'))
    end

    it 'retorna slots de 60 minutos correctamente' do
      result = call(slot_duration_minutes: 60)
      slots = result[:agents][user.id][:available_slots][monday.iso8601]

      expect(slots).to include(slot('2026-06-08', '09:00:00'))
      expect(slots).to include(slot('2026-06-08', '16:00:00'))
      expect(slots).not_to include(slot('2026-06-08', '16:30:00'))
    end

    it 'excluye slots dentro de un schedule_block' do
      create(:schedule_block, account_user: account_user, day_of_week: 1,
                              start_hour: 12, start_minutes: 0,
                              end_hour: 13, end_minutes: 0)

      result = call
      slots = result[:agents][user.id][:available_slots][monday.iso8601]

      expect(slots).not_to include(slot('2026-06-08', '12:00:00'))
      expect(slots).not_to include(slot('2026-06-08', '12:30:00'))
      expect(slots).to include(slot('2026-06-08', '13:00:00'))
      expect(slots).to include(slot('2026-06-08', '11:30:00'))
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

      expect(slots).not_to include(slot('2026-06-08', '10:00:00'))
      expect(slots).to include(slot('2026-06-08', '09:30:00'))
      expect(slots).to include(slot('2026-06-08', '10:30:00'))
    end

    it 'no devuelve slots para días cerrados (domingo cerrado por defecto)' do
      result = call(start_date: sunday, end_date: sunday)
      expect(result[:agents][user.id][:available_slots]).not_to have_key(sunday.iso8601)
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
      expect(result[:agents][user.id][:name]).to eq(user.name)
      expect(result[:agents][user.id][:timezone]).to eq('UTC')
    end

    it 'popula by_datetime con UTC como clave' do
      result = call
      expect(result[:by_datetime]).to have_key('2026-06-08T09:00:00Z')
      expect(result[:by_datetime]['2026-06-08T09:00:00Z']).to include(user.id)
    end

    it 'los slots en available_slots están en el timezone del agente' do
      account_user.update!(timezone: 'America/Hermosillo') # UTC-7
      result = call
      slots = result[:agents][user.id][:available_slots][monday.iso8601]

      # El agente trabaja 9am-5pm en su tz (America/Hermosillo, UTC-7)
      # → los slots deben aparecer como 09:00:00-07:00, no como UTC
      expect(slots.first).to include('-07:00')
      expect(slots.first).to start_with('2026-06-08T09:00:00')
    end

    it 'by_datetime usa UTC aunque el agente tenga timezone distinto' do
      account_user.update!(timezone: 'America/Hermosillo') # UTC-7
      result = call
      # 9am Hermosillo = 16:00 UTC
      expect(result[:by_datetime]).to have_key('2026-06-08T16:00:00Z')
      expect(result[:by_datetime]['2026-06-08T16:00:00Z']).to include(user.id)
    end

    it 'no expone timezone de cuenta en la raíz' do
      result = call
      expect(result).not_to have_key(:timezone)
    end
  end
end
