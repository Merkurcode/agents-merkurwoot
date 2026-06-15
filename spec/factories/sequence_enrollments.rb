# frozen_string_literal: true

FactoryBot.define do
  factory :sequence_enrollment do
    status { 'active' }
    enrolled_at { Time.current }
    current_step { 0 }

    after(:build) do |enrollment|
      unless enrollment.conversation
        account = create(:account)
        whatsapp_channel = create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false)
        whatsapp_inbox = create(:inbox, channel: whatsapp_channel, account: account)
        enrollment.conversation = create(:conversation, account: account, inbox: whatsapp_inbox)
      end

      enrollment.lead_follow_up_sequence ||= create(
        :lead_follow_up_sequence,
        account: enrollment.conversation.account,
        inbox: enrollment.conversation.inbox
      )
    end

    trait :completed do
      status { 'completed' }
      completed_at { Time.current }
      completion_reason { 'Contact replied' }
    end

    trait :cancelled do
      status { 'cancelled' }
      completed_at { Time.current }
      completion_reason { 'Agent assigned' }
    end

    trait :failed do
      status { 'failed' }
      completed_at { Time.current }
      completion_reason { 'Max retries exceeded' }
    end

    trait :with_result_schema do
      after(:create) do |enrollment|
        enrollment.lead_follow_up_sequence.update!(
          result_schema: [
            { 'key' => 'outcome', 'label' => 'Outcome', 'type' => 'select',
              'required' => true, 'options' => [{ 'label' => 'Converted', 'value' => 'converted' },
                                                { 'label' => 'Not interested', 'value' => 'not_interested' }] },
            { 'key' => 'notes', 'label' => 'Notes', 'type' => 'text', 'required' => false }
          ]
        )
      end
    end
  end
end
