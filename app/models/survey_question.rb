# == Schema Information
#
# Table name: survey_questions
#
#  id            :bigint           not null, primary key
#  input_type    :integer          default("text")
#  position      :integer          default(0), not null
#  question_text :text             not null
#  question_type :integer          default("open_ended"), not null
#  required      :boolean          default(FALSE), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  survey_id     :bigint           not null
#
# Indexes
#
#  index_survey_questions_on_survey_id               (survey_id)
#  index_survey_questions_on_survey_id_and_position  (survey_id,position)
#
# Foreign Keys
#
#  fk_rails_...  (survey_id => surveys.id)
#

class SurveyQuestion < ApplicationRecord
  belongs_to :survey
  has_many :survey_question_options, dependent: :destroy
  has_many :survey_answers, dependent: :destroy

  enum question_type: { open_ended: 0, multiple_choice: 1, file: 2 }
  enum input_type: { text: 0, number: 1 }

  validates :question_text, presence: true, length: { maximum: 500 }
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :validate_options_for_multiple_choice
  validate :validate_accepted_file_types_for_file_questions

  default_scope { order(position: :asc) }

  accepts_nested_attributes_for :survey_question_options, allow_destroy: true

  # Available file types for file questions
  AVAILABLE_FILE_TYPES = [
    { value: 'image/*', label: 'Images' },
    { value: 'video/*', label: 'Videos' },
    { value: 'audio/*', label: 'Audio' },
    { value: 'application/pdf', label: 'PDF' },
    { value: 'application/msword', label: 'Word (DOC)' },
    { value: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', label: 'Word (DOCX)' },
    { value: 'application/vnd.ms-excel', label: 'Excel (XLS)' },
    { value: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', label: 'Excel (XLSX)' },
    { value: 'application/vnd.ms-powerpoint', label: 'PowerPoint (PPT)' },
    { value: 'application/vnd.openxmlformats-officedocument.presentationml.presentation', label: 'PowerPoint (PPTX)' },
    { value: 'text/plain', label: 'Text files' },
    { value: 'text/csv', label: 'CSV' },
    { value: 'application/zip', label: 'ZIP' }
  ].freeze

  def accepted_file_types_list
    accepted_file_types || []
  end

  private

  def validate_options_for_multiple_choice
    return unless multiple_choice?

    return unless survey_question_options.reject(&:marked_for_destruction?).size < 2

    errors.add(:base, 'Multiple choice questions must have at least 2 options')
  end

  def validate_accepted_file_types_for_file_questions
    return unless file?

    if accepted_file_types.blank? || !accepted_file_types.is_a?(Array) || accepted_file_types.empty?
      errors.add(:accepted_file_types, 'must have at least one file type for file questions')
    end
  end
end
