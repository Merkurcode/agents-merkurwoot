# frozen_string_literal: true

class AddWhatsappGroupIdToConversations < ActiveRecord::Migration[7.0]
  def up
    add_column :conversations, :whatsapp_group_id, :string
    add_index :conversations, :whatsapp_group_id

    # Migrate existing data from additional_attributes
    execute <<-SQL
      UPDATE conversations
      SET whatsapp_group_id = additional_attributes->>'whatsapp_group_id'
      WHERE conversation_type = 1
        AND additional_attributes->>'whatsapp_group_id' IS NOT NULL
    SQL
  end

  def down
    remove_column :conversations, :whatsapp_group_id
  end
end
