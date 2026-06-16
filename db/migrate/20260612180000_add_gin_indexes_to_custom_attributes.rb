# frozen_string_literal: true

class AddGinIndexesToCustomAttributes < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    unless index_exists?(:contacts, :custom_attributes, name: 'index_contacts_on_custom_attributes_gin')
      add_index :contacts, :custom_attributes,
                using: :gin,
                name: 'index_contacts_on_custom_attributes_gin',
                algorithm: :concurrently
    end

    unless index_exists?(:conversations, :custom_attributes, name: 'index_conversations_on_custom_attributes_gin')
      add_index :conversations, :custom_attributes,
                using: :gin,
                name: 'index_conversations_on_custom_attributes_gin',
                algorithm: :concurrently
    end
  end

  def down
    remove_index :contacts, name: 'index_contacts_on_custom_attributes_gin' if index_exists?(:contacts, :custom_attributes, name: 'index_contacts_on_custom_attributes_gin')
    remove_index :conversations, name: 'index_conversations_on_custom_attributes_gin' if index_exists?(:conversations, :custom_attributes, name: 'index_conversations_on_custom_attributes_gin')
  end
end
