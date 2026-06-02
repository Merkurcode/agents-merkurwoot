class CreateChannelVoiceAgents < ActiveRecord::Migration[7.0]
  def change
    create_table :channel_voice_agents do |t|
      t.integer :account_id, null: false
      t.timestamps null: false
    end

    add_index :channel_voice_agents, :account_id, unique: true
  end
end
