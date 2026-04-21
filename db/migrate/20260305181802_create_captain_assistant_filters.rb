class CreateCaptainAssistantFilters < ActiveRecord::Migration[7.1]
  def change
    create_table :captain_assistant_filters do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :captain_assistant, null: false, foreign_key: { to_table: :captain_assistants }, index: true
      t.string :name, null: false
      t.jsonb :filters, null: false, default: []
      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end
