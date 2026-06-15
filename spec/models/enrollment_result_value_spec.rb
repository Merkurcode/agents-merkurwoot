# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EnrollmentResultValue do
  describe 'associations' do
    it { is_expected.to belong_to(:sequence_enrollment) }
    it { is_expected.to belong_to(:lead_follow_up_sequence) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:field_key) }
  end

  describe 'scopes' do
    let(:sequence) { create(:lead_follow_up_sequence) }
    let(:other_sequence) { create(:lead_follow_up_sequence) }
    let(:enrollment) { create(:sequence_enrollment, lead_follow_up_sequence: sequence, conversation: create(:conversation, account: sequence.account, inbox: sequence.inbox)) }
    let!(:result1) { create(:enrollment_result_value, sequence_enrollment: enrollment, lead_follow_up_sequence: sequence, field_key: 'outcome', value: 'converted') }
    let!(:result2) { create(:enrollment_result_value, sequence_enrollment: enrollment, lead_follow_up_sequence: sequence, field_key: 'notes', value: 'Good prospect') }
    let!(:other_result) { create(:enrollment_result_value, lead_follow_up_sequence: other_sequence) }

    describe '.for_sequence' do
      it 'returns only values for the given sequence' do
        expect(described_class.for_sequence(sequence.id)).to contain_exactly(result1, result2)
      end
    end

    describe '.for_field' do
      it 'returns only values for the given field key' do
        expect(described_class.for_sequence(sequence.id).for_field('outcome')).to contain_exactly(result1)
      end
    end
  end
end
