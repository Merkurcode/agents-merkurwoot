# frozen_string_literal: true

module Crm
  module Salesforce
    # Salesforce CRM Processor Service
    #
    # Implements CRM actions for Salesforce API
    class ProcessorService < Crm::BaseProcessorService
      def initialize(hook)
        super(hook)
        @lead_client = Crm::Salesforce::Api::LeadClient.new(hook)
        @opportunity_client = Crm::Salesforce::Api::OpportunityClient.new(hook)
        @task_client = Crm::Salesforce::Api::TaskClient.new(hook)
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
        when 'create_opportunity'
          create_opportunity(params)
        when 'create_task'
          create_task(params)
        when 'create_event'
          create_event(params)
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
        # Verificar si tiene access_token
        return false unless @hook.credentials['access_token'].present?

        # Si el token está expirado, intentar refrescarlo
        if @hook.token_expired?
          Rails.logger.info "Salesforce token expired, attempting refresh..."
          @hook.refresh_token_if_needed
          @hook.reload
        end

        # Verificar de nuevo después del posible refresh
        @hook.credentials['access_token'].present? && !@hook.token_expired?
      rescue StandardError => e
        Rails.logger.error "Salesforce authentication check failed: #{e.message}"
        false
      end

      # ============================================================================
      # LEAD OPERATIONS
      # ============================================================================

      # Create lead in Salesforce
      #
      # @param params [Hash] Lead parameters
      # @return [Hash] Result with success status and lead_id
      def create_lead(params)
        contact = find_contact_from_params(params)
        return { success: false, error: 'Contact not found' } unless contact

        # Check if lead already exists
        external_id = contact.additional_attributes&.dig('external', 'salesforce_lead_id')
        if external_id.present?
          Rails.logger.info "Lead already exists in Salesforce: #{external_id}"
          return { success: true, lead_id: external_id, action: 'existing' }
        end

        # Map contact to Salesforce lead format
        mapper = Crm::Salesforce::Mappers::ContactMapper.new(contact)
        lead_data = mapper.map_to_lead(custom_fields: params[:lead_custom_fields] || {})

        # Create lead in Salesforce
        response = @lead_client.create_lead(lead_data)

        if response && response['id'].present?
          lead_id = response['id']

          # Store external ID
          store_external_id(contact, lead_id, 'salesforce_lead_id')

          Rails.logger.info "Lead created successfully in Salesforce: #{lead_id}"
          { success: true, lead_id: lead_id, action: 'created', response: response }
        else
          { success: false, error: 'Failed to create lead', response: response }
        end
      rescue StandardError => e
        Rails.logger.error "Error creating lead in Salesforce: #{e.message}"
        { success: false, error: e.message }
      end

      # Update lead in Salesforce
      #
      # @param params [Hash] Lead parameters with lead_id
      # @return [Hash] Result with success status
      def update_lead(params)
        lead_id = params[:lead_id] || get_external_id_from_params(params, 'salesforce_lead_id')
        return { success: false, error: 'Lead ID not provided' } unless lead_id

        contact = find_contact_from_params(params)
        return { success: false, error: 'Contact not found' } unless contact

        # Map contact to Salesforce format
        mapper = Crm::Salesforce::Mappers::ContactMapper.new(contact)
        lead_data = mapper.map_to_lead(custom_fields: params[:lead_custom_fields] || {})

        # Update lead
        response = @lead_client.update_lead(lead_id, lead_data)

        if response
          Rails.logger.info "Lead updated successfully in Salesforce: #{lead_id}"
          { success: true, lead_id: lead_id, action: 'updated' }
        else
          { success: false, error: 'Failed to update lead', response: response }
        end
      rescue StandardError => e
        Rails.logger.error "Error updating lead in Salesforce: #{e.message}"
        { success: false, error: e.message }
      end

      # ============================================================================
      # OPPORTUNITY OPERATIONS
      # ============================================================================

      # Create opportunity in Salesforce
      #
      # @param params [Hash] Opportunity parameters
      # @return [Hash] Result with success status and opportunity_id
      def create_opportunity(params)
        contact = find_contact_from_params(params)
        return { success: false, error: 'Contact not found' } unless contact

        # Map to Salesforce opportunity format
        opportunity_data = Crm::Salesforce::Mappers::OpportunityMapper.map_opportunity(
          name: params[:name] || "Opportunity for #{contact.name}",
          amount: params[:amount],
          close_date: params[:close_date] || (Date.current + 30.days).to_s,
          stage_name: params[:stage_name] || 'Prospecting',
          contact_id: contact.id,
          description: params[:description]
        )

        response = @opportunity_client.create_opportunity(opportunity_data)

        if response && response['id'].present?
          opportunity_id = response['id']

          Rails.logger.info "Opportunity created successfully in Salesforce: #{opportunity_id}"
          { success: true, opportunity_id: opportunity_id, response: response }
        else
          { success: false, error: 'Failed to create opportunity', response: response }
        end
      rescue StandardError => e
        Rails.logger.error "Error creating opportunity in Salesforce: #{e.message}"
        { success: false, error: e.message }
      end

      # ============================================================================
      # TASK OPERATIONS
      # ============================================================================

      # Create task in Salesforce
      #
      # @param params [Hash] Task parameters
      # @return [Hash] Result with success status and task_id
      def create_task(params)
        contact = find_contact_from_params(params)
        lead_id = contact&.additional_attributes&.dig('external', 'salesforce_lead_id')

        # Map to Salesforce task format
        task_data = Crm::Salesforce::Mappers::ActivityMapper.map_task(
          subject: params[:subject] || 'Task from Chatwoot',
          description: params[:description],
          due_date: params[:due_date],
          priority: params[:priority] || 'Normal',
          status: params[:status] || 'Not Started',
          who_id: lead_id # WhoId links to Lead or Contact
        )

        response = @task_client.create_task(task_data)

        if response && response['id'].present?
          task_id = response['id']

          Rails.logger.info "Task created successfully in Salesforce: #{task_id}"
          { success: true, task_id: task_id, response: response }
        else
          { success: false, error: 'Failed to create task', response: response }
        end
      rescue StandardError => e
        Rails.logger.error "Error creating task in Salesforce: #{e.message}"
        { success: false, error: e.message }
      end

      # ============================================================================
      # EVENT OPERATIONS
      # ============================================================================

      # Create event (meeting) in Salesforce
      #
      # @param params [Hash] Event parameters
      # @option params [Integer] :appointment_id Chatwoot appointment ID (opcional)
      # @option params [Hash] :metadata Metadata del agente AI
      # @return [Hash] Result with success status and event_id
      def create_event(params)
        metadata = params[:metadata] || {}
        appointment = params[:appointment_id].present? ? Appointment.find_by(id: params[:appointment_id]) : nil

        contact = appointment&.contact || find_contact_from_params(params)
        lead_id = contact&.additional_attributes&.dig('external', 'salesforce_lead_id')

        if !appointment && metadata.blank? && params[:subject].blank?
          return { success: false, error: 'Appointment or event details required' }
        end

        event_params = if appointment
                         { who_id: lead_id }
                       else
                         {
                           subject: metadata['event_title'] || metadata['subject'] || params[:subject],
                           description: metadata['description'] || params[:description],
                           start_time: metadata['start_time'] || metadata['scheduled_at'] || params[:start_time],
                           end_time: metadata['end_time'] || params[:end_time],
                           venue: metadata['venue'] || params[:venue],
                           who_id: lead_id
                         }
                       end

        event_data = Crm::Salesforce::Mappers::ActivityMapper.map_event(
          appointment || event_params,
          event_params
        )

        response = @task_client.create_event(event_data)

        if response && response['id'].present?
          event_id = response['id']
          appointment.store_external_id('salesforce', event_id) if appointment

          Rails.logger.info "Event created successfully in Salesforce: #{event_id}"
          { success: true, event_id: event_id, response: response }
        else
          { success: false, error: 'Failed to create event', response: response }
        end
      rescue StandardError => e
        Rails.logger.error "Error creating event in Salesforce: #{e.message}"
        { success: false, error: e.message }
      end

      # ============================================================================
      # NOTE OPERATIONS
      # ============================================================================

      # Add note to lead in Salesforce (uses ContentNote object)
      #
      # @param params [Hash] Note parameters
      # @return [Hash] Result with success status and note_id
      def add_note(params)
        contact = find_contact_from_params(params)
        lead_id = contact&.additional_attributes&.dig('external', 'salesforce_lead_id')

        return { success: false, error: 'Lead not found in Salesforce' } unless lead_id

        note_text = params[:note_text]
        return { success: false, error: 'Note text not provided' } unless note_text

        note_title = params[:note_title] || 'Note from Chatwoot'

        response = @lead_client.add_note(lead_id, note_title, note_text)

        if response && response['id'].present?
          note_id = response['id']

          Rails.logger.info "Note added to lead #{lead_id}"
          { success: true, note_id: note_id, response: response }
        else
          { success: false, error: 'Failed to add note', response: response }
        end
      rescue StandardError => e
        Rails.logger.error "Error adding note in Salesforce: #{e.message}"
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

      def get_external_id_from_params(params, external_key = 'salesforce_lead_id')
        contact = find_contact_from_params(params)
        contact&.additional_attributes&.dig('external', external_key)
      end

      def store_external_id(contact, external_id, external_key = 'salesforce_lead_id')
        contact.additional_attributes ||= {}
        contact.additional_attributes['external'] ||= {}
        contact.additional_attributes['external'][external_key] = external_id
        contact.save(validate: false)
      end

      def get_external_id(contact, external_key = 'salesforce_lead_id')
        contact.additional_attributes&.dig('external', external_key)
      end
    end
  end
end
