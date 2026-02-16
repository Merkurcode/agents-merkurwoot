# frozen_string_literal: true

module Crm
  module Zoho
    class TicketAttachmentJob < ApplicationJob
      queue_as :default
      retry_on StandardError, attempts: 3, wait: 5.seconds

      def perform(ticket_id:, blob_id:, hook_id:)
        ticket = Ticket.find(ticket_id)
        blob = ActiveStorage::Blob.find(blob_id)
        hook = Integrations::Hook.find(hook_id)

        zoho_ticket_id = ticket.external_id_for('zoho')
        return unless zoho_ticket_id

        client = Crm::Zoho::Api::TicketClient.new(hook)

        blob.open do |tempfile|
          result = client.upload_attachment(zoho_ticket_id, tempfile)
          store_attachment_id(ticket, blob_id, result) if result && result['id']
        end
      end

      private

      def store_attachment_id(ticket, blob_id, result)
        ticket.metadata ||= {}
        ticket.metadata['zoho_attachments'] ||= {}
        ticket.metadata['zoho_attachments'][blob_id.to_s] = result['id']
        ticket.save!
      end
    end
  end
end
