class Channel::VoiceAgent < ApplicationRecord
  include Channelable

  self.table_name = 'channel_voice_agents'

  validates :account_id, uniqueness: true

  def name
    'Agente de Voz'
  end
end
