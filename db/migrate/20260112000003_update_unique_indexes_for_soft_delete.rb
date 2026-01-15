class UpdateUniqueIndexesForSoftDelete < ActiveRecord::Migration[7.1]
  def change
    # Contacts - email unique index (allow duplicate emails if original is discarded)
    remove_index :contacts, name: 'uniq_email_per_account_contact'
    add_index :contacts, 'LOWER(email), account_id',
              unique: true,
              where: 'discarded_at IS NULL',
              name: 'uniq_email_per_account_contact'

    # Contacts - identifier unique index (allow duplicate identifiers if original is discarded)
    remove_index :contacts, name: 'uniq_identifier_per_account_contact'
    add_index :contacts, [:identifier, :account_id],
              unique: true,
              where: 'discarded_at IS NULL',
              name: 'uniq_identifier_per_account_contact'

    # Conversations - display_id unique index (allow duplicate display_ids if original is discarded)
    remove_index :conversations, name: 'index_conversations_on_account_id_and_display_id'
    add_index :conversations, [:account_id, :display_id],
              unique: true,
              where: 'discarded_at IS NULL',
              name: 'index_conversations_on_account_id_and_display_id'
  end
end
