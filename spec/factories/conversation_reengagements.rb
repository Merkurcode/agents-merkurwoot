# frozen_string_literal: true

FactoryBot.define do
  factory :conversation_reengagement do
    status { 'active' }
    current_attempt { 0 }
    trigger_started_at { 1.hour.ago }
    next_fire_at { 1.minute.ago }
    processing_started_at { nil }
    metadata { {} }

    association :conversation
    association :agent_bot
  end
end
