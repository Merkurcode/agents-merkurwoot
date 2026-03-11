# frozen_string_literal: true

class AddRoleToConversationParticipants < ActiveRecord::Migration[7.0]
  def change
    add_column :conversation_participants, :role, :integer, default: 0, null: false
    add_index :conversation_participants, [:conversation_id, :role]
  end
end
