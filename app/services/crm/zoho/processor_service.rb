# frozen_string_literal: true

module Crm
  module Zoho
    # Zoho CRM Processor Service
    #
    # Implements CRM actions for Zoho CRM API
    class ProcessorService < Crm::BaseProcessorService
      def initialize(hook)
        super(hook)
        @lead_client = Crm::Zoho::Api::LeadClient.new(hook)
        @activity_client = Crm::Zoho::Api::ActivityClient.new(hook)
      end

      # ============================================================================
      # ACTION DISPATCHER
      # ============================================================================

      # Execute a CRM action based on action_type
      #
      # @param action_type [String] Type of action (create_lead, update_lead, etc.)
      # @param params [Hash] Action parameters
      # @return [Hash] Result with success status
      def execute_action(action_type, params = {})
        case action_type.to_s
        when 'create_lead'
          create_lead(params)
        when 'update_lead'
          update_lead(params)
        when 'create_task'
          create_task(params)
        when 'create_call'
          create_call(params)
        when 'create_event'
          create_event(params)
        when 'add_tag'
          add_tag(params)
        when 'remove_tag'
          remove_tag(params)
        when 'add_note'
          add_note(params)
        else
          { success: false, error: "Unknown action type: #{action_type}" }
        end
      end

      # ============================================================================
      # AUTHENTICATION
      # ============================================================================

      def authenticated?
        credentials['access_token'].present? && !hook.token_expired?
      rescue StandardError => e
        Rails.logger.error "Zoho authentication check failed: #{e.message}"
        false
      end

      # ============================================================================
      # LEAD OPERATIONS
      # ============================================================================

      # Create lead in Zoho CRM
      #
      # @param params [Hash] Lead parameters
      # @option params [String] :contact_first_name
      # @option params [String] :contact_last_name
      # @option params [String] :email
      # @option params [String] :phone
      # @option params [Hash] :lead_custom_fields Custom fields for lead
      # @option params [Hash] :contact_custom_fields Custom fields for contact
      # @return [Hash] Result with success status and lead_id
      def create_lead(params)
        contact = find_contact_from_params(params)
        return { success: false, error: 'Contact not found' } unless contact

        # Check if lead already exists
        external_id = contact.additional_attributes&.dig('external', 'zoho_lead_id')
        if external_id.present?
          Rails.logger.info "Lead already exists in Zoho: #{external_id}"
          return { success: true, lead_id: external_id, action: 'existing' }
        end

        # Map contact to Zoho lead format
        mapper = Crm::Zoho::Mappers::ContactMapper.new(contact)
        lead_data = mapper.map_to_lead(custom_fields: params[:lead_custom_fields] || {})

        # Create lead in Zoho
        response = @lead_client.create_lead(lead_data)

        if response && response['data']&.any?
          lead_record = response['data'].first
          lead_id = lead_record['details']['id']

          # Store external ID
          store_external_id(contact, lead_id)

          Rails.logger.info "Lead created successfully in Zoho: #{lead_id}"
          { success: true, lead_id: lead_id, action: 'created', response: lead_record }
        else
          { success: false, error: 'Failed to create lead', response: response }
        end
      rescue StandardError => e
        Rails.logger.error "Error creating lead in Zoho: #{e.message}"
        { success: false, error: e.message }
      end

      # Update lead in Zoho CRM
      #
      # @param params [Hash] Lead parameters with lead_id
      # @return [Hash] Result with success status
      def update_lead(params)
        lead_id = params[:lead_id] || get_external_id_from_params(params)
        return { success: false, error: 'Lead ID not provided' } unless lead_id

        contact = find_contact_from_params(params)
        return { success: false, error: 'Contact not found' } unless contact

        # Map contact to Zoho format
        mapper = Crm::Zoho::Mappers::ContactMapper.new(contact)
        lead_data = mapper.map_to_lead(custom_fields: params[:lead_custom_fields] || {})

        # Update lead
        response = @lead_client.update_lead(lead_id, lead_data)

        if response && response['data']&.any?
          Rails.logger.info "Lead updated successfully in Zoho: #{lead_id}"
          { success: true, lead_id: lead_id, action: 'updated' }
        else
          { success: false, error: 'Failed to update lead', response: response }
        end
      rescue StandardError => e
        Rails.logger.error "Error updating lead in Zoho: #{e.message}"
        { success: false, error: e.message }
      end

      # ============================================================================
      # TASK OPERATIONS
      # ============================================================================

      # Create task in Zoho CRM
      #
      # @param params [Hash] Task parameters
      # @option params [String] :subject Task subject
      # @option params [String] :description Task description
      # @option params [String] :due_date Due date
      # @option params [String] :priority Priority (High, Normal, Low)
      # @option params [String] :status Status
      # @option params [String] :owner_id Zoho owner ID
      # @option params [Boolean] :send_notification Send notification
      # @return [Hash] Result with success status and task_id
      def create_task(params)
        contact = find_contact_from_params(params)
        lead_id = contact&.additional_attributes&.dig('external', 'zoho_lead_id')

        # Map to Zoho task format
        task_data = Crm::Zoho::Mappers::ActivityMapper.map_task(
          subject: params[:subject],
          description: params[:description],
          due_date: params[:due_date],
          priority: params[:priority],
          status: params[:status],
          owner_id: params[:owner_id],
          contact_id: nil, # Zoho tasks use What_Id for leads
          lead_id: lead_id,
          se_module: 'Leads',
          send_notification: params[:send_notification]
        )

        response = @activity_client.create_task(task_data)

        if response && response['data']&.any?
          task_record = response['data'].first
          task_id = task_record['details']['id']

          Rails.logger.info "Task created successfully in Zoho: #{task_id}"
          { success: true, task_id: task_id, response: task_record }
        else
          { success: false, error: 'Failed to create task', response: response }
        end
      rescue StandardError => e
        Rails.logger.error "Error creating task in Zoho: #{e.message}"
        { success: false, error: e.message }
      end

      # ============================================================================
      # CALL OPERATIONS
      # ============================================================================

      # Create call log in Zoho CRM
      #
      # @param params [Hash] Call parameters
      # @option params [String] :subject Call subject
      # @option params [String] :description Call description
      # @option params [String] :call_type Call type (Inbound/Outbound)
      # @option params [String] :start_time Start time (ISO 8601)
      # @option params [Integer] :duration Duration in seconds
      # @return [Hash] Result with success status and call_id
      def create_call(params)
        contact = find_contact_from_params(params)
        lead_id = contact&.additional_attributes&.dig('external', 'zoho_lead_id')
        metadata = params[:metadata] || {}

        # Priorizamos metadata (AI) sobre params (configuración fija del flow)
        subject     = metadata['call_subject'].presence || metadata['subject'].presence || params[:subject]
        description = metadata['call_description'].presence || metadata['description'].presence || params[:description]
        start_time  = metadata['scheduled_at'].presence || metadata['start_time'].presence || params[:start_time]

        # Map to Zoho call format
        call_data = Crm::Zoho::Mappers::ActivityMapper.map_call(
          subject: subject,
          description: description,
          call_type: params[:call_type],
          start_time: start_time,
          duration: params[:duration],
          contact_id: nil, # Zoho calls use What_Id for leads
          lead_id: lead_id,
          se_module: 'Leads',
          status: 'Scheduled'
        )

        response = @activity_client.create_call(call_data)

        if response && response['data']&.any?
          call_record = response['data'].first
          call_id = call_record['details']['id']

          Rails.logger.info "Call created successfully in Zoho: #{call_id}"
          { success: true, call_id: call_id, response: call_record }
        else
          { success: false, error: 'Failed to create call', response: response }
        end
      rescue StandardError => e
        Rails.logger.error "Error creating call in Zoho: #{e.message}"
        { success: false, error: e.message }
      end

      # ============================================================================
      # EVENT OPERATIONS
      # ============================================================================

      # Create event in Zoho CRM from Chatwoot appointment
      #
      # @param params [Hash] Event parameters
      # @option params [Integer] :appointment_id Chatwoot appointment ID
      # @option params [String] :owner_id Zoho owner ID
      # @option params [Boolean] :send_notification Send notification
      # @return [Hash] Result with success status and event_id
      def create_event(params)
        appointment_id = params[:appointment_id]
        metadata = params[:metadata] || {}
        appointment = appointment_id.present? ? Appointment.find_by(id: appointment_id) : nil

        # Identificar el contacto y lead_id de Zoho
        contact = appointment&.contact || find_contact_from_params(params)
        lead_id = contact&.additional_attributes&.dig('external', 'zoho_lead_id')

        # Si no hay cita ni metadata suficiente, fallamos (mantenemos compatibilidad)
        if !appointment && metadata.blank? && params[:subject].blank?
          return { success: false, error: 'Appointment or metadata required to create event' }
        end

        # Preparamos los parámetros base
        event_params = if appointment
                         params # Pasar params directamente para que map_event los combine con appointment
                       else
                         {
                           event_title: metadata['event_title'] || metadata['subject'] || params[:subject],
                           description: metadata['event_description'] || metadata['description'] || params[:description],
                           start_time:  metadata['start_time'] || metadata['scheduled_at'] || params[:start_time],
                           end_time:    metadata['end_time'] || params[:end_time],
                           venue:       metadata['venue'] || params[:venue],
                           lead_id:     lead_id,
                           se_module:   'Leads',
                           owner_id:    params[:owner_id],
                           send_notification: params[:send_notification] || false
                         }
                       end

        # Map to Zoho event format
        event_data = Crm::Zoho::Mappers::ActivityMapper.map_event(
          appointment || event_params,
          appointment ? event_params : {}
        )

        response = @activity_client.create_event(event_data)

        if response && response['data']&.any?
          event_record = response['data'].first
          event_id = event_record['details']['id']

          # Si venía de una cita, guardamos el ID externo
          appointment.store_external_id('zoho', event_id) if appointment

          Rails.logger.info "Event created successfully in Zoho: #{event_id}"
          { success: true, event_id: event_id, response: event_record }
        else
          { success: false, error: 'Failed to create event', response: response }
        end
      rescue StandardError => e
        Rails.logger.error "Error creating event in Zoho: #{e.message}"
        { success: false, error: e.message }
      end

      # ============================================================================
      # TAG OPERATIONS
      # ============================================================================

      # Add tag to lead in Zoho CRM
      #
      # @param params [Hash] Tag parameters
      # @option params [String] :tag_name Tag name
      # @return [Hash] Result with success status
      def add_tag(params)
        contact = find_contact_from_params(params)
        lead_id = contact&.additional_attributes&.dig('external', 'zoho_lead_id')

        return { success: false, error: 'Lead not found in Zoho' } unless lead_id

        tag_name = params[:tag_name]
        return { success: false, error: 'Tag name not provided' } unless tag_name

        response = @lead_client.add_tags(lead_id, [tag_name], module_name: 'Leads')

        if response && response['data']&.any?
          Rails.logger.info "Tag '#{tag_name}' added to lead #{lead_id}"
          { success: true, tag_name: tag_name }
        else
          { success: false, error: 'Failed to add tag', response: response }
        end
      rescue StandardError => e
        Rails.logger.error "Error adding tag in Zoho: #{e.message}"
        { success: false, error: e.message }
      end

      # Remove tag from lead in Zoho CRM
      #
      # @param params [Hash] Tag parameters
      # @option params [String] :tag_name Tag name
      # @return [Hash] Result with success status
      def remove_tag(params)
        contact = find_contact_from_params(params)
        lead_id = contact&.additional_attributes&.dig('external', 'zoho_lead_id')

        return { success: false, error: 'Lead not found in Zoho' } unless lead_id

        tag_name = params[:tag_name]
        return { success: false, error: 'Tag name not provided' } unless tag_name

        response = @lead_client.remove_tags([lead_id], [tag_name], module_name: 'Leads')

        if response && response['data']&.any?
          Rails.logger.info "Tag '#{tag_name}' removed from lead #{lead_id}"
          { success: true, tag_name: tag_name }
        else
          { success: false, error: 'Failed to remove tag', response: response }
        end
      rescue StandardError => e
        Rails.logger.error "Error removing tag in Zoho: #{e.message}"
        { success: false, error: e.message }
      end

      # ============================================================================
      # NOTE OPERATIONS
      # ============================================================================

      # Add note to lead in Zoho CRM
      #
      # @param params [Hash] Note parameters
      # @option params [String] :note_text Note content
      # @option params [String] :note_title Note title (optional)
      # @return [Hash] Result with success status and note_id
      def add_note(params)
        contact = find_contact_from_params(params)
        lead_id = contact&.additional_attributes&.dig('external', 'zoho_lead_id')

        return { success: false, error: 'Lead not found in Zoho' } unless lead_id

        note_text = params[:note_text]
        return { success: false, error: 'Note text not provided' } unless note_text

        note_title = params[:note_title] || 'Note from Chatwoot'

        response = @lead_client.add_note(lead_id, note_title, note_text, se_module: 'Leads')

        if response && response['data']&.any?
          note_record = response['data'].first
          note_id = note_record['details']['id']

          Rails.logger.info "Note added to lead #{lead_id}"
          { success: true, note_id: note_id, response: note_record }
        else
          { success: false, error: 'Failed to add note', response: response }
        end
      rescue StandardError => e
        Rails.logger.error "Error adding note in Zoho: #{e.message}"
        { success: false, error: e.message }
      end

      # ============================================================================
      # HELPER METHODS
      # ============================================================================

      protected

      def build_client
        # Clients are initialized in constructor
        @lead_client
      end

      private

      def find_contact_from_params(params)
        contact_id = params[:contact_id]
        return Contact.find_by(id: contact_id) if contact_id

        # Try to find by email or phone if provided
        if params[:email].present?
          Contact.find_by(email: params[:email], account_id: hook.account_id)
        elsif params[:phone].present?
          Contact.find_by(phone_number: params[:phone], account_id: hook.account_id)
        end
      end

      def get_external_id_from_params(params)
        contact = find_contact_from_params(params)
        contact&.additional_attributes&.dig('external', 'zoho_lead_id')
      end

      def store_external_id(contact, external_id)
        contact.additional_attributes ||= {}
        contact.additional_attributes['external'] ||= {}
        contact.additional_attributes['external']['zoho_lead_id'] = external_id
        contact.save(validate: false)
      end

      def get_external_id(contact)
        contact.additional_attributes&.dig('external', 'zoho_lead_id')
      end
    end
  end
end
