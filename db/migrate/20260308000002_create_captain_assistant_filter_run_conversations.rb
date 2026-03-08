class CreateCaptainAssistantFilterRunConversations < ActiveRecord::Migration[7.1]
  def change
    create_table :captain_assistant_filter_run_conversations do |t|
      t.references :filter_run, null: false,
                   foreign_key: { to_table: :captain_assistant_filter_runs }, index: true
      t.references :conversation, null: false, foreign_key: true, index: true
      t.integer :status, null: false, default: 0
      t.text :error_message
      t.datetime :processed_at

      t.timestamps
    end

    add_index :captain_assistant_filter_run_conversations,
              %i[filter_run_id conversation_id], unique: true
  end
end
