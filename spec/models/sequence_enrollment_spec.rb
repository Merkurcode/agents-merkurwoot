# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SequenceEnrollment do
  let(:account) { create(:account) }
  let(:whatsapp_channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
  let(:inbox) { create(:inbox, channel: whatsapp_channel, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:sequence) { create(:lead_follow_up_sequence, account: account, inbox: inbox) }
  let(:enrollment) { create(:sequence_enrollment, conversation: conversation, lead_follow_up_sequence: sequence) }

  describe 'associations' do
    it { is_expected.to belong_to(:conversation) }
    it { is_expected.to belong_to(:lead_follow_up_sequence) }
    it { is_expected.to have_many(:enrollment_events).dependent(:destroy) }
    it { is_expected.to have_many(:result_values).class_name('EnrollmentResultValue').dependent(:destroy_async) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:enrolled_at) }
    it { is_expected.to validate_inclusion_of(:status).in_array(%w[active completed cancelled failed]) }
  end

  describe 'scopes' do
    let!(:active_enrollment) { create(:sequence_enrollment, conversation: conversation, lead_follow_up_sequence: sequence) }
    let!(:completed_enrollment) { create(:sequence_enrollment, :completed, conversation: create(:conversation, account: account, inbox: inbox), lead_follow_up_sequence: sequence) }
    let!(:cancelled_enrollment) { create(:sequence_enrollment, :cancelled, conversation: create(:conversation, account: account, inbox: inbox), lead_follow_up_sequence: sequence) }

    it '.active returns only active enrollments' do
      expect(described_class.active).to include(active_enrollment)
      expect(described_class.active).not_to include(completed_enrollment, cancelled_enrollment)
    end

    it '.completed returns only completed enrollments' do
      expect(described_class.completed).to include(completed_enrollment)
      expect(described_class.completed).not_to include(active_enrollment)
    end
  end

  describe '#active?' do
    it 'returns true when status is active' do
      expect(enrollment.active?).to be true
    end

    it 'returns false when status is completed' do
      enrollment.update!(status: 'completed', completed_at: Time.current)
      expect(enrollment.active?).to be false
    end
  end

  describe '#finished?' do
    it 'returns false when active' do
      expect(enrollment.finished?).to be false
    end

    it 'returns true when completed' do
      enrollment.update!(status: 'completed', completed_at: Time.current)
      expect(enrollment.finished?).to be true
    end

    it 'returns true when cancelled' do
      enrollment.update!(status: 'cancelled', completed_at: Time.current)
      expect(enrollment.finished?).to be true
    end

    it 'returns true when failed' do
      enrollment.update!(status: 'failed', completed_at: Time.current)
      expect(enrollment.finished?).to be true
    end
  end

  describe '#complete!' do
    it 'transitions to completed with reason' do
      enrollment.complete!('Contact replied')
      expect(enrollment.status).to eq('completed')
      expect(enrollment.completion_reason).to eq('Contact replied')
      expect(enrollment.completed_at).to be_present
    end

    it 'creates a completed enrollment event' do
      expect { enrollment.complete!('All steps completed') }
        .to change(EnrollmentEvent, :count).by(1)
      expect(enrollment.enrollment_events.last.event_type).to eq('completed')
    end
  end

  describe '#cancel!' do
    it 'transitions to cancelled with reason' do
      enrollment.cancel!('Agent assigned')
      expect(enrollment.status).to eq('cancelled')
      expect(enrollment.completion_reason).to eq('Agent assigned')
    end

    it 'creates a cancelled enrollment event' do
      expect { enrollment.cancel!('Agent assigned') }
        .to change(EnrollmentEvent, :count).by(1)
      expect(enrollment.enrollment_events.last.event_type).to eq('cancelled')
    end
  end

  describe '#set_result!' do
    before do
      sequence.update!(
        result_schema: [
          { 'key' => 'outcome', 'label' => 'Outcome', 'type' => 'select', 'required' => true,
            'options' => [{ 'label' => 'Converted', 'value' => 'converted' }] },
          { 'key' => 'notes', 'label' => 'Notes', 'type' => 'text', 'required' => false }
        ]
      )
    end

    context 'when captured by a human' do
      it 'creates result values for each field' do
        expect do
          enrollment.set_result!({ 'outcome' => 'converted', 'notes' => 'Good call' }, captured_by: 'human')
        end.to change(EnrollmentResultValue, :count).by(2)
      end

      it 'sets result_captured_by and result_captured_at' do
        enrollment.set_result!({ 'outcome' => 'converted' }, captured_by: 'human')
        expect(enrollment.result_captured_by).to eq('human')
        expect(enrollment.result_captured_at).to be_present
      end

      it 'marks result_complete true when all required fields are present' do
        enrollment.set_result!({ 'outcome' => 'converted' }, captured_by: 'human')
        expect(enrollment.result_complete).to be true
      end

      it 'marks result_complete false when required fields are missing' do
        enrollment.set_result!({ 'notes' => 'some note' }, captured_by: 'human')
        expect(enrollment.result_complete).to be false
      end

      it 'replaces previous result values on re-submission' do
        enrollment.set_result!({ 'outcome' => 'converted' }, captured_by: 'human')
        enrollment.set_result!({ 'outcome' => 'not_interested', 'notes' => 'Changed mind' }, captured_by: 'human')

        expect(enrollment.result_values.count).to eq(2)
        expect(enrollment.result_values.find_by(field_key: 'outcome').value).to eq('not_interested')
      end
    end

    context 'when captured by an agent_bot' do
      it 'sets result_captured_by to agent_bot' do
        enrollment.set_result!({ 'outcome' => 'converted' }, captured_by: 'agent_bot')
        expect(enrollment.result_captured_by).to eq('agent_bot')
      end
    end
  end

  describe '#result_as_hash' do
    it 'returns an empty hash when no result values exist' do
      expect(enrollment.result_as_hash).to eq({})
    end

    it 'returns a hash keyed by field_key' do
      create(:enrollment_result_value,
             sequence_enrollment: enrollment,
             lead_follow_up_sequence: sequence,
             field_key: 'outcome',
             value: 'converted')
      create(:enrollment_result_value,
             sequence_enrollment: enrollment,
             lead_follow_up_sequence: sequence,
             field_key: 'notes',
             value: 'Great prospect')

      expect(enrollment.result_as_hash).to eq({ 'outcome' => 'converted', 'notes' => 'Great prospect' })
    end
  end

  describe 'after_commit callback: enqueue_result_analysis_webhook' do
    let(:agent_bot) { create(:agent_bot, account: account) }

    before do
      sequence.update!(
        result_schema: [{ 'key' => 'outcome', 'label' => 'Outcome', 'type' => 'select',
                          'required' => true, 'options' => [{ 'label' => 'Converted', 'value' => 'converted' }] }]
      )
      inbox.create_agent_bot_inbox!(agent_bot: agent_bot, account: account)
    end

    it 'enqueues FollowUpResultAnalysisJob when enrollment finishes with schema and no results' do
      expect do
        enrollment.complete!('Contact replied')
      end.to have_enqueued_job(FollowUpResultAnalysisJob).with(enrollment.id)
    end

    it 'does not enqueue job when result_schema is blank' do
      sequence.update!(result_schema: [])
      expect do
        enrollment.complete!('Contact replied')
      end.not_to have_enqueued_job(FollowUpResultAnalysisJob)
    end

    it 'does not enqueue job when result values already exist' do
      create(:enrollment_result_value,
             sequence_enrollment: enrollment,
             lead_follow_up_sequence: sequence,
             field_key: 'outcome',
             value: 'converted')

      expect do
        enrollment.complete!('Contact replied')
      end.not_to have_enqueued_job(FollowUpResultAnalysisJob)
    end

    it 'does not enqueue job when status stays active' do
      expect do
        enrollment.update!(current_step: 1)
      end.not_to have_enqueued_job(FollowUpResultAnalysisJob)
    end
  end
end
