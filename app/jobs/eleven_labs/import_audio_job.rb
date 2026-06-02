module ElevenLabs
  class ImportAudioJob < ApplicationJob
    queue_as :default

    def perform(conversation_id, blob_id)
      conversation = Conversation.find_by(id: conversation_id)
      blob = ActiveStorage::Blob.find_by(id: blob_id)

      return unless conversation && blob

      message = conversation.messages.build(
        account_id: conversation.account_id,
        inbox_id: conversation.inbox_id,
        message_type: :incoming,
        content_type: :text,
        sender: conversation.contact
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
