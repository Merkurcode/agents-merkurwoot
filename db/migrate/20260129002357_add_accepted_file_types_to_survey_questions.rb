class AddAcceptedFileTypesToSurveyQuestions < ActiveRecord::Migration[7.1]
  def change
    add_column :survey_questions, :accepted_file_types, :jsonb, default: []
  end
end
