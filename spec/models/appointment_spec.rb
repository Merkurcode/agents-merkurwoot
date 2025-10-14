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
end
