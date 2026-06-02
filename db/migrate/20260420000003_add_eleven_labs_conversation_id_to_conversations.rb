class AddElevenLabsConversationIdToConversations < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_column :conversations, :eleven_labs_conversation_id, :string

    add_index :conversations, :eleven_labs_conversation_id,
              unique: true,
              where: 'eleven_labs_conversation_id IS NOT NULL',
              algorithm: :concurrently
  end
end
