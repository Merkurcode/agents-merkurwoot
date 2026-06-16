class AddResultFieldsToSequenceEnrollments < ActiveRecord::Migration[7.0]
  def change
    add_column :sequence_enrollments, :result_captured_by, :string
    add_column :sequence_enrollments, :result_captured_at, :datetime
    add_column :sequence_enrollments, :result_complete, :boolean, default: false, null: false
  end
end
