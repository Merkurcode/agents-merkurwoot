json.payload do
  json.conversations do
    json.array! @result[:conversations] do |conversation|
      json.id conversation.display_id
      json.account_id conversation.account_id
      json.created_at conversation.created_at.to_i
      json.message do
        json.partial! 'message', formats: [:json], message: conversation.messages.try(:first)
      end
      json.contact do
        contact = conversation.contact || Contact.with_discarded.find_by(id: conversation.contact_id)
        if contact.present?
          json.partial! 'contact', formats: [:json], contact: contact
        else
          # Ultimate fallback if contact was hard deleted
          json.id conversation.contact_id
          json.name I18n.t('contacts.deleted.name')
          json.email nil
          json.phone_number nil
          json.thumbnail ''
        end
      end
      json.inbox do
        json.partial! 'inbox', formats: [:json], inbox: conversation.inbox if conversation.try(:inbox).present?
      end
      json.agent do
        json.partial! 'agent', formats: [:json], agent: conversation.assignee if conversation.try(:assignee).present?
      end

      json.additional_attributes conversation.additional_attributes
    end
  end
end
