# frozen_string_literal: true

FactoryBot.define do
  factory :enrollment_result_value do
    field_key { 'outcome' }
    value { 'converted' }

    after(:build) do |result_value|
      unless result_value.sequence_enrollment
        account = create(:account)
        whatsapp_channel = create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false)
        whatsapp_inbox = create(:inbox, channel: whatsapp_channel, account: account)
        conversation = create(:conversation, account: account, inbox: whatsapp_inbox)
        sequence = create(:lead_follow_up_sequence, account: account, inbox: whatsapp_inbox)
        result_value.sequence_enrollment = create(:sequence_enrollment,
                                                  conversation: conversation,
                                                  lead_follow_up_sequence: sequence)
      end

      result_value.lead_follow_up_sequence ||= result_value.sequence_enrollment.lead_follow_up_sequence
    end
  end
end
