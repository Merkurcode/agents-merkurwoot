# frozen_string_literal: true

FactoryBot.define do
  factory :schedule_block do
    association :account_user
    day_of_week   { 1 }
    start_hour    { 12 }
    start_minutes { 0 }
    end_hour      { 13 }
    end_minutes   { 0 }
    reason        { 'Almuerzo' }

    before(:create) do |block|
      block.account = block.account_user.account
    end
  end
end
