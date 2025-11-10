class AddUniqueIndexToMetaCampaignInteractionsMessageId < ActiveRecord::Migration[7.1]
  def change
    remove_index :meta_campaign_interactions, :message_id
    add_index :meta_campaign_interactions, :message_id, unique: true
  end
end
