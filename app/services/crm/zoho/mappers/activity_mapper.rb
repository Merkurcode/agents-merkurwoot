# frozen_string_literal: true

module Crm
  module Zoho
    module Mappers
      # Maps Nauto Console data to Zoho CRM Task/Event format
      class ActivityMapper
        # Map Chatwoot data to Zoho Task format
        #
        # @param params [Hash] Task parameters
        # @option params [String] :contact_id Zoho contact ID
        # @option params [String] :lead_id Zoho lead ID (What_Id)
        # @option params [String] :owner_id Zoho owner ID
        # @option params [String] :subject Task subject
        # @option params [String] :description Task description
        # @option params [String] :due_date Due date (YYYY-MM-DD)
        # @option params [String] :priority Priority (High, Normal, Low)
        # @option params [String] :status Status (Not Started, In Progress, Completed)
        # @option params [Boolean] :send_notification Send email notification
        # @return [Hash] Zoho Task data
        def self.map_task(params = {})
          task_data = {
            Subject: params[:subject] || 'Follow up from Chatwoot',
            Description: params[:description],
            Due_Date: params[:due_date] || (Date.current + 1.day).to_s,
            Priority: params[:priority] || 'Normal',
            Status: params[:status] || 'Not Started',
            Send_Notification_Email: params[:send_notification] || false,
            send_notification: params[:send_notification] || false
          }.compact

          # Add Who_Id (Contact) if provided
          if params[:contact_id].present?
            task_data[:Who_Id] = { id: params[:contact_id] }
          end

          # Add What_Id (Lead or other related record) if provided
          if params[:lead_id].present?
            task_data[:What_Id] = { id: params[:lead_id] }
            task_data[:'$se_module'] = params[:se_module] || 'Leads'
          end

          # Add Owner if specified
          if params[:owner_id].present?
            task_data[:Owner] = { id: params[:owner_id] }
          end

          task_data
        end

        # Map Chatwoot Appointment to Zoho Event format
        #
        # @param appointment [Appointment] Chatwoot appointment
        # @param params [Hash] Additional parameters
        # @option params [String] :contact_id Zoho contact ID
        # @option params [String] :lead_id Zoho lead ID
        # @option params [String] :owner_id Zoho owner ID
        # @option params [Array<Hash>] :participants Event participants
        # @return [Hash] Zoho Event data
        def self.map_event(appointment, params = {})
          event_data = {
            Event_Title: appointment.description || 'Meeting from Chatwoot',
            Start_DateTime: format_datetime(appointment.scheduled_at),
            End_DateTime: format_datetime(appointment.ended_at || appointment.scheduled_at + 1.hour),
            Description: build_event_description(appointment),
            send_notification: params[:send_notification] || false
          }.compact

          # Add venue/location based on appointment type
          case appointment.appointment_type
          when 'physical_visit'
            event_data[:Venue] = appointment.location || 'Office'
          when 'digital_meeting'
            event_data[:Venue] = 'Video Call'
            event_data[:Description] = "#{event_data[:Description]}\n\nMeeting URL: #{appointment.meeting_url}"
          when 'phone_call'
            event_data[:Venue] = 'Phone Call'
            event_data[:Description] = "#{event_data[:Description]}\n\nPhone: #{appointment.phone_number}"
          end

          # Add Who_Id (Contact) if provided
          if params[:contact_id].present?
            event_data[:Who_Id] = { id: params[:contact_id] }
          end

          # Add What_Id (Lead or other related record) if provided
          if params[:lead_id].present?
            event_data[:What_Id] = { id: params[:lead_id] }
            event_data[:'$se_module'] = params[:se_module] || 'Leads'
          end

          # Add Owner if specified
          if params[:owner_id].present?
            event_data[:Owner] = { id: params[:owner_id] }
          end

          # Add participants if provided
          if params[:participants].present?
            event_data[:Participants] = params[:participants]
          end

          event_data
        end

        # Map phone call to Zoho Call format
        #
        # @param params [Hash] Call parameters
        # @option params [String] :contact_id Zoho contact ID
        # @option params [String] :lead_id Zoho lead ID
        # @option params [String] :subject Call subject
        # @option params [String] :description Call description
        # @option params [String] :call_type Call type (Inbound/Outbound)
        # @option params [DateTime] :start_time Call start time
        # @option params [Integer] :duration Call duration in seconds
        # @return [Hash] Zoho Call data
        def self.map_call(params = {})
          {
            Subject: params[:subject] || 'Call from Chatwoot',
            Call_Type: params[:call_type] || 'Outbound',
            Call_Start_Time: format_datetime(params[:start_time] || Time.current),
            Call_Duration: params[:duration] || 0,
            Description: params[:description],
            Who_Id: params[:contact_id].present? ? { id: params[:contact_id] } : nil,
            What_Id: params[:lead_id].present? ? { id: params[:lead_id] } : nil
          }.compact
        end

        # Format datetime to Zoho format (ISO 8601 with timezone)
        #
        # @param datetime [DateTime, Time] DateTime to format
        # @return [String] Formatted datetime
        def self.format_datetime(datetime)
          return nil unless datetime

          datetime.iso8601
        end

        # Build event description from appointment
        #
        # @param appointment [Appointment] Chatwoot appointment
        # @return [String] Event description
        def self.build_event_description(appointment)
          parts = []

          parts << appointment.description if appointment.description.present?
          parts << "Type: #{appointment.appointment_type.humanize}"
          parts << "Status: #{appointment.status.humanize}"

          if appointment.participant_agents.any?
            agent_names = appointment.participant_agents.map(&:name).join(', ')
            parts << "Agents: #{agent_names}"
          end

          parts.join("\n")
        end
      end
    end
  end
end
