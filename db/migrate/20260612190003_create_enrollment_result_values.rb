class CreateEnrollmentResultValues < ActiveRecord::Migration[7.0]
  def change
    create_table :enrollment_result_values do |t|
      t.references :sequence_enrollment,     null: false, foreign_key: true, index: true
      t.references :lead_follow_up_sequence, null: false, foreign_key: true, index: true
      t.string :field_key, null: false
      t.text   :value

      t.timestamps
    end

    add_index :enrollment_result_values, [:lead_follow_up_sequence_id, :field_key],
              name: 'idx_enrollment_results_seq_key'
    add_index :enrollment_result_values, [:lead_follow_up_sequence_id, :field_key, :value],
              name: 'idx_enrollment_results_seq_key_value'
  end
end
