class CreateCaptainAssistantFilterRuns < ActiveRecord::Migration[7.1]
  def change
    create_table :captain_assistant_filter_runs do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :assistant_filter, null: false,
                   foreign_key: { to_table: :captain_assistant_filters }, index: true
      t.integer :triggered_by_id
      t.datetime :scheduled_at
      t.text :message
      t.integer :status, null: false, default: 0
      t.integer :conversations_total, null: false, default: 0
      t.integer :conversations_processed, null: false, default: 0

      t.timestamps
    end
  end
end
