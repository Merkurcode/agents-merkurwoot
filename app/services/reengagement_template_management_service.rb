# frozen_string_literal: true

class ReengagementTemplateManagementService
  DEFAULT_LANGUAGE = 'es_MX'

  def initialize(inbox)
    @inbox = inbox
  end

  def template_status
    template = @inbox.reengagement_config&.dig('template')
    return { template_exists: false } unless template

    get_whatsapp_template_status(template)
  rescue StandardError => e
    Rails.logger.error "Error fetching reengagement template status: #{e.message}"
    { service_error: e.message }
  end

  def create_template(template_params)
    validate_template_params!(template_params)

    delete_existing_template_if_needed

    result = create_whatsapp_template(template_params)
    update_inbox_reengagement_config(result, template_params) if result[:success]

    result
  rescue StandardError => e
    Rails.logger.error "Error creating reengagement template: #{e.message}"
    { success: false, service_error: 'Template creation failed' }
  end

  private

  def validate_template_params!(template_params)
    raise ActionController::ParameterMissing, 'message' if template_params[:message].blank?
  end

  def create_whatsapp_template(template_params)
    template_config = build_template_config(template_params)
    Whatsapp::ReengagementTemplateService.new(@inbox.channel).create_template(template_config)
  end

  def build_template_config(template_params)
    {
      message: template_params[:message],
      language: template_params[:language] || DEFAULT_LANGUAGE,
      template_name: Whatsapp::ReengagementTemplateNameService.reengagement_template_name(@inbox.id)
    }
  end

  def update_inbox_reengagement_config(result, template_params)
    current_config = @inbox.reengagement_config || {}
    template_data = {
      'name' => result[:template_name],
      'template_id' => result[:template_id],
      'language' => result[:language],
      'created_at' => Time.current.iso8601
    }
    updated_config = current_config.merge(
      'message' => template_params[:message],
      'language' => template_params[:language] || DEFAULT_LANGUAGE,
      'template' => template_data
    )
    @inbox.update!(reengagement_config: updated_config)
  end

  def get_whatsapp_template_status(template)
    template_name = template['name'] ||
                    Whatsapp::ReengagementTemplateNameService.reengagement_template_name(@inbox.id)
    status_result = Whatsapp::ReengagementTemplateService.new(@inbox.channel).get_template_status(template_name)

    if status_result[:success]
      {
        template_exists: true,
        template_name: template_name,
        status: status_result[:template][:status],
        template_id: status_result[:template][:id]
      }
    else
      {
        template_exists: false,
        error: 'Template not found'
      }
    end
  end

  def delete_existing_template_if_needed
    template = @inbox.reengagement_config&.dig('template')
    return true if template.blank?

    template_name = template['name']
    return true if template_name.blank?

    service = Whatsapp::ReengagementTemplateService.new(@inbox.channel)
    template_status = service.get_template_status(template_name)
    return true unless template_status[:success]

    deletion_result = service.delete_template(template_name)
    if deletion_result[:success]
      Rails.logger.info "Deleted existing reengagement template '#{template_name}' for inbox #{@inbox.id}"
      true
    else
      Rails.logger.warn "Failed to delete reengagement template '#{template_name}' for inbox #{@inbox.id}: #{deletion_result[:response_body]}"
      false
    end
  rescue StandardError => e
    Rails.logger.error "Error during reengagement template deletion for inbox #{@inbox.id}: #{e.message}"
    false
  end
end
