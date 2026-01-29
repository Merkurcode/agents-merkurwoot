# == Schema Information
#
# Table name: survey_answers
#
#  id                        :bigint           not null, primary key
#  answer_text               :text
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  account_id                :bigint           not null
#  contact_id                :bigint           not null
#  survey_question_id        :bigint           not null
#  survey_question_option_id :bigint
#
# Indexes
#
#  index_survey_answers_on_account_id                         (account_id)
#  index_survey_answers_on_account_id_and_created_at          (account_id,created_at)
#  index_survey_answers_on_contact_id                         (contact_id)
#  index_survey_answers_on_contact_id_and_survey_question_id  (contact_id,survey_question_id) UNIQUE
#  index_survey_answers_on_survey_question_id                 (survey_question_id)
#  index_survey_answers_on_survey_question_option_id          (survey_question_option_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (survey_question_id => survey_questions.id)
#  fk_rails_...  (survey_question_option_id => survey_question_options.id)
#

class SurveyAnswer < ApplicationRecord
  belongs_to :account
  belongs_to :contact
  belongs_to :survey_question
  belongs_to :survey_question_option, optional: true

  has_one_attached :file

  validates :account_id, presence: true
  validates :contact_id, presence: true
  validates :survey_question_id, presence: true
  validate :answer_presence
  validate :answer_type_consistency
  validate :file_type_validation, if: -> { file.attached? }

  private

  def answer_presence
    # File questions require a file attachment
    if survey_question&.file?
      errors.add(:file, 'must be attached for file questions') unless file.attached?
      return
    end

    return if answer_text.present? || survey_question_option_id.present?

    errors.add(:base, 'Either answer_text or survey_question_option_id must be present')
  end

  def answer_type_consistency
    return unless survey_question

    if survey_question.open_ended? && survey_question_option_id.present?
      errors.add(:survey_question_option_id, 'should not be present for open-ended questions')
    elsif survey_question.multiple_choice? && answer_text.present?
      errors.add(:answer_text, 'should not be present for multiple choice questions')
    elsif survey_question.file? && (answer_text.present? || survey_question_option_id.present?)
      errors.add(:base, 'File questions should not have answer_text or option_id')
    end
  end

  def file_type_validation
    return unless survey_question&.file? && file.attached?

    accepted_types = survey_question.accepted_file_types_list
    return if accepted_types.empty?

    content_type = file.content_type
    type_accepted = accepted_types.any? do |accepted_type|
      if accepted_type.end_with?('/*')
        # Wildcard match (e.g., image/*)
        content_type.start_with?(accepted_type.gsub('/*', '/'))
      else
        # Exact match
        content_type == accepted_type
      end
    end

    return if type_accepted

    errors.add(:file, "type '#{content_type}' is not accepted. Accepted types: #{accepted_types.join(', ')}")
  end
end
