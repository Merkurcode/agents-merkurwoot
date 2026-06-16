class AddReengagementConfigToInboxes < ActiveRecord::Migration[7.1]
  def change
    add_column :inboxes, :reengagement_config, :jsonb, default: {}, null: false
  end
end
