json.meta do
  json.labels @conversation.cached_label_list_array
  json.additional_attributes @conversation.additional_attributes
  contact = @conversation.contact || Contact.with_discarded.find_by(id: @conversation.contact_id)
  if contact.present?
    json.contact contact.push_event_data
  else
    # Ultimate fallback if contact was hard deleted
    json.contact({
      id: @conversation.contact_id,
      name: I18n.t('contacts.deleted.name'),
      email: nil,
      phone_number: nil,
      thumbnail: '',
      availability_status: nil,
      additional_attributes: {},
      custom_attributes: {}
    })
  end
  json.assignee @conversation.assignee.push_event_data if @conversation.assignee.present?
  json.agent_last_seen_at @conversation.agent_last_seen_at
  json.assignee_last_seen_at @conversation.assignee_last_seen_at
end

json.payload do
  json.array! @messages do |message|
    json.partial! 'api/v1/models/message', message: message
  end
end
