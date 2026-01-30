# frozen_string_literal: true

module Crm
  module Salesforce
    module Mappers
      # Maps Nauto Console data to Salesforce Task/Event format
      class ActivityMapper
        # Map to Salesforce Task format
        #
        # @param params [Hash] Task parameters
        # @return [Hash] Salesforce Task data
        def self.map_task(subject:, description: nil, due_date: nil, priority: 'Normal', status: 'Not Started', who_id: nil, what_id: nil)
          {
            Subject: subject,
            Description: description,
            ActivityDate: due_date || Date.current.to_s,
            Priority: priority, # High, Normal, Low
            Status: status, # Not Started, In Progress, Completed, Waiting on someone else, Deferred
            WhoId: who_id, # Lead or Contact ID
            WhatId: what_id # Account, Opportunity, etc.
          }.compact
        end

        # Map to Salesforce Event format
        #
        # @param appointment [Appointment] Chatwoot appointment
        # @param params [Hash] Additional parameters
        # @return [Hash] Salesforce Event data
        def self.map_event(appointment, who_id: nil, what_id: nil)
          {
            Subject: appointment.description.presence || 'Meeting from Chatwoot',
            StartDateTime: format_datetime(appointment.scheduled_at),
            EndDateTime: format_datetime(appointment.ended_at || appointment.scheduled_at + 1.hour),
            Location: appointment.location,
            Description: appointment.additional_notes,
            WhoId: who_id, # Lead or Contact ID
            WhatId: what_id, # Account, Opportunity, etc.
            IsAllDayEvent: false
          }.compact
        end

        # Format datetime for Salesforce (ISO 8601)
        #
        # @param datetime [DateTime, Time] DateTime object
        # @return [String] ISO 8601 formatted datetime
        def self.format_datetime(datetime)
          return nil unless datetime

          datetime.utc.iso8601
        end
      end
    end
  end
end
