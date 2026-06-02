class AddElevenLabsAgentIdToAccounts < ActiveRecord::Migration[7.0]
  def change
    add_column :accounts, :eleven_labs_agent_id, :string
    add_index :accounts, :eleven_labs_agent_id, unique: true
  end
end
