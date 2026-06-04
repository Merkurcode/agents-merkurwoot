module ElevenLabs
  class ImportAudioJob < ApplicationJob
    queue_as :default

    def perform(conversation_id, blob_id)
      conversation = Conversation.find_by(id: conversation_id)
      blob = ActiveStorage::Blob.find_by(id: blob_id)

      return unless conversation && blob

      last_message_at = conversation.messages.maximum(:created_at) || conversation.created_at
      audio_timestamp = last_message_at + 1.second

      message = conversation.messages.build(
        account_id: conversation.account_id,
        inbox_id: conversation.inbox_id,
        message_type: :incoming,
        content_type: :text,
        content: 'Voice call recording',
        sender: conversation.contact,
        status: :read,
        created_at: audio_timestamp
      )

      message.attachments.build(
        account_id: conversation.account_id,
        file_type: :audio,
        file: blob
      )

      message.save!
    end
  end
end
