# This file is used to render conversation data search API response.

json.id conversation.display_id
json.uuid conversation.uuid
json.created_at conversation.created_at.to_i
json.contact do
  contact = conversation.contact || Contact.with_discarded.find_by(id: conversation.contact_id)
  if contact.present?
    json.id contact.id
    json.name contact.name
  else
    # Ultimate fallback if contact was hard deleted
    json.id conversation.contact_id
    json.name I18n.t('contacts.deleted.name')
  end
end
json.inbox do
  json.id conversation.inbox.id
  json.name conversation.inbox.name
  json.channel_type conversation.inbox.channel_type
end
json.messages do
  json.array! conversation.messages do |message|
    json.content message.content
    json.id message.id
    json.sender_name message.sender.name if message.sender
    json.message_type message.message_type_before_type_cast
    json.created_at message.created_at.to_i
  end
end
json.account_id conversation.account_id
