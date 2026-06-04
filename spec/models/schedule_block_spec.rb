# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ScheduleBlock do
  let(:account_user) { create(:account_user) }

  describe 'associations' do
    it { is_expected.to belong_to(:account_user) }
    it { is_expected.to belong_to(:account) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:day_of_week) }
    it { is_expected.to validate_presence_of(:start_hour) }
    it { is_expected.to validate_presence_of(:end_hour) }

    it 'is valid with correct attributes' do
      block = build(:schedule_block, account_user: account_user)
      expect(block).to be_valid
    end

    it 'rejects day_of_week outside 0..6' do
      block = build(:schedule_block, account_user: account_user, day_of_week: 7)
      expect(block).not_to be_valid
      expect(block.errors[:day_of_week]).to be_present
    end

    it 'rejects start_hour outside 0..23' do
      block = build(:schedule_block, account_user: account_user, start_hour: 24)
      expect(block).not_to be_valid
    end

    it 'rejects end_hour outside 0..23' do
      block = build(:schedule_block, account_user: account_user, end_hour: 25)
      expect(block).not_to be_valid
    end

    it 'rejects end before start (same hour)' do
      block = build(:schedule_block, account_user: account_user,
                                     start_hour: 13, start_minutes: 0,
                                     end_hour: 12, end_minutes: 0)
      expect(block).not_to be_valid
      expect(block.errors[:end_hour]).to include('must be after start time')
    end

    it 'rejects end equal to start' do
      block = build(:schedule_block, account_user: account_user,
                                     start_hour: 12, start_minutes: 30,
                                     end_hour: 12, end_minutes: 30)
      expect(block).not_to be_valid
    end

    it 'rejects duplicate [account_user_id, day_of_week, start_hour, start_minutes]' do
      create(:schedule_block, account_user: account_user, day_of_week: 1, start_hour: 12, start_minutes: 0)
      dup = build(:schedule_block, account_user: account_user, day_of_week: 1, start_hour: 12, start_minutes: 0)
      expect(dup).not_to be_valid
      expect(dup.errors[:account_user_id]).to be_present
    end
  end

  describe 'callbacks' do
    it 'assigns account from account_user before save' do
      block = create(:schedule_block, account_user: account_user)
      expect(block.account_id).to eq(account_user.account_id)
    end
  end
end
