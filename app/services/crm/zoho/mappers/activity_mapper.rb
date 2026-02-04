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

          # Who_Id: enlace al Lead o Contacto involucrado
          if params[:lead_id].present?
            task_data[:Who_Id] = { id: params[:lead_id] }
          elsif params[:contact_id].present?
            task_data[:Who_Id] = { id: params[:contact_id] }
          end

          # Add Owner if specified
          if params[:owner_id].present?
            task_data[:Owner] = { id: params[:owner_id] }
          end

          task_data
        end

        # Map Nauto Console Appointment to Zoho Event format
        #
        # @param appointment [Appointment] Nauto Console appointment
        # @param params [Hash] Additional parameters
        # @option params [String] :contact_id Zoho contact ID
        # @option params [String] :lead_id Zoho lead ID
        # @option params [String] :owner_id Zoho owner ID
        # @option params [Array<Hash>] :participants Event participants
        # @return [Hash] Zoho Event data
        def self.map_event(appointment, params = {})
          event_data = {
            Subject: appointment.description || 'Meeting from Nauto Console',
            Start_DateTime: format_datetime(appointment.scheduled_at),
            End_DateTime: format_datetime(appointment.ended_at || appointment.scheduled_at + 1.hour),
            Description: build_event_description(appointment),
            Send_Notification_Email: params[:send_notification] || false
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
          status = params[:status] || 'Scheduled'
          start_time = params[:start_time] || Time.current

          # Para llamadas programadas, Zoho requiere que la hora sea estrictamente a futuro.
          # Agregamos un margen de 5 minutos si es "ahora" para evitar errores de sincronización.
          if status == 'Scheduled' && params[:start_time].blank?
            start_time = Time.current + 5.minutes
          end

          call_data = {
            Subject: params[:subject] || (status == 'Scheduled' ? 'Scheduled Call from Nauto Console' : 'Call from Nauto Console'),
            Call_Type: params[:call_type] || 'Outbound',
            Call_Start_Time: format_datetime(start_time),
            Call_Status: status,            # Standard field
            Outgoing_Call_Status: status,   # Field name from error message (V2.1+)
            Outbound_Call_Status: status,   # Field name from documentation
            Description: params[:description]
          }

          # Zoho rechaza duración cero, y para programadas debe omitirse.
          if status == 'Completed'
            duration_secs = params[:duration].to_i
            hours   = duration_secs / 3600
            minutes = (duration_secs % 3600) / 60
            call_data[:Call_Duration] = format('%<hh>02d:%<mm>02d', hh: hours, mm: minutes)
          end

          # En Zoho V2/V3, Who_Id es para Contactos/Leads
          # What_Id es para otros módulos (Deals, etc)
          # Sin embargo, si se usa What_Id para Leads (según ProcessorService),
          # se REQUIERE especificar $se_module.
          if params[:lead_id].present?
            call_data[:What_Id] = { id: params[:lead_id] }
            call_data[:'$se_module'] = params[:se_module] || 'Leads'
          elsif params[:contact_id].present?
            call_data[:Who_Id] = { id: params[:contact_id] }
          end

          call_data.compact
        end

        # Format datetime to Zoho format (ISO 8601 with timezone)
        #
        # @param datetime [DateTime, Time] DateTime to format
        # @return [String] Formatted datetime
        def self.format_datetime(datetime)
          return nil unless datetime
          return datetime if datetime.is_a?(String)

          datetime.iso8601
        end

        # Build event description from appointment
        #
        # @param appointment [Appointment] Nauto Console appointment
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
