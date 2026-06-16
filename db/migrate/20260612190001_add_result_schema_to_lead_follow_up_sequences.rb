class AddResultSchemaToLeadFollowUpSequences < ActiveRecord::Migration[7.0]
  def change
    add_column :lead_follow_up_sequences, :result_schema, :jsonb, default: []
  end
end
