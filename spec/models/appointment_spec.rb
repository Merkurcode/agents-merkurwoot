# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Appointment do
  describe 'associations' do
    it { is_expected.to belong_to(:contact) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:start_time) }
    it { is_expected.to validate_presence_of(:end_time) }

    context 'when end_time is before start_time' do
      let(:contact) { create(:contact) }
      let(:appointment) { build(:appointment, contact: contact, start_time: Time.zone.now, end_time: 1.hour.ago) }

      it 'is invalid' do
        expect(appointment).not_to be_valid
        expect(appointment.errors[:end_time]).to include('must be after start time')
      end
    end

    context 'when end_time is after start_time' do
      let(:contact) { create(:contact) }
      let(:appointment) { build(:appointment, contact: contact, start_time: Time.zone.now, end_time: 1.hour.from_now) }

      it 'is valid' do
        expect(appointment).to be_valid
      end
    end
  end

  describe '#within_owner_working_hours' do
    let(:account)      { create(:account) }
    let(:owner)        { create(:user, account: account, role: :agent) }
    let(:account_user) { owner.account_users.find_by!(account: account) }
    let(:monday_wh)    { account_user.working_hours.find_by!(day_of_week: 1) }
    let(:contact)      { create(:contact, account: account) }

    def build_appt(scheduled_at:)
      Appointment.new(
        account:          account,
        contact:          contact,
        owner_id:         owner.id,
        scheduled_at:     scheduled_at,
        appointment_type: 'phone_call',
        phone_number:     '+1234567890',
        status:           'scheduled'
      )
    end

    context 'sin working_hours configurados' do
      it 'no agrega error (skip graceful)' do
        appt = build_appt(scheduled_at: Time.zone.parse('2026-06-08 10:00:00 UTC'))
        appt.valid?
        expect(appt.errors[:scheduled_at]).to be_empty
      end
    end

    context 'con día cerrado (closed_all_day)' do
      before { monday_wh.update!(closed_all_day: true, open_hour: nil, open_minutes: nil, close_hour: nil, close_minutes: nil) }

      it 'agrega error con mensaje de día no laborable' do
        appt = build_appt(scheduled_at: Time.zone.parse('2026-06-08 10:00:00 UTC'))
        appt.valid?
        expect(appt.errors[:scheduled_at]).to include('the advisor does not work on this day')
      end
    end

    context 'con horario laboral 9-17' do
      # El account_user ya tiene working_hours por defecto (Lun-Vie 9-17)

      it 'es válido a las 10:00' do
        appt = build_appt(scheduled_at: Time.zone.parse('2026-06-08 10:00:00 UTC'))
        appt.valid?
        expect(appt.errors[:scheduled_at]).to be_empty
      end

      it 'agrega error fuera de horario (08:00)' do
        appt = build_appt(scheduled_at: Time.zone.parse('2026-06-08 08:00:00 UTC'))
        appt.valid?
        expect(appt.errors[:scheduled_at]).to include('the appointment time is outside the advisor working hours')
      end

      context 'con schedule_block de 12:00 a 13:00' do
        before do
          create(:schedule_block, account_user: account_user, day_of_week: 1,
                                  start_hour: 12, start_minutes: 0,
                                  end_hour: 13, end_minutes: 0)
        end

        it 'agrega error cuando la cita cae dentro del bloque (12:30)' do
          appt = build_appt(scheduled_at: Time.zone.parse('2026-06-08 12:30:00 UTC'))
          appt.valid?
          expect(appt.errors[:scheduled_at]).to include('the advisor is not available at this time')
        end

        it 'es válido a las 13:00 (justo al terminar el bloque)' do
          appt = build_appt(scheduled_at: Time.zone.parse('2026-06-08 13:00:00 UTC'))
          appt.valid?
          expect(appt.errors[:scheduled_at]).to be_empty
        end
      end
    end
  end

  describe 'callbacks' do
    describe 'access_token generation' do
      let(:contact) { create(:contact) }

      it 'generates access_token before create' do
        appointment = build(:appointment, contact: contact)
        expect(appointment.access_token).to be_nil

        appointment.save!
        expect(appointment.access_token).to be_present
        expect(appointment.access_token).to be_a(String)
      end

      it 'generates unique access_token for each appointment' do
        appointment1 = create(:appointment, contact: contact)
        appointment2 = create(:appointment, contact: contact)

        expect(appointment1.access_token).to be_present
        expect(appointment2.access_token).to be_present
        expect(appointment1.access_token).not_to eq(appointment2.access_token)
      end
    end
  end
end
