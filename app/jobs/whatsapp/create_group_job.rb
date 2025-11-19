# frozen_string_literal: true

class Whatsapp::CreateGroupJob < ApplicationJob
  queue_as :default

  def perform(conversation_id)
    conversation = Conversation.find_by(id: conversation_id)
    return unless conversation

    Whatsapp::GroupService.new(conversation: conversation).create_group
  end
end
