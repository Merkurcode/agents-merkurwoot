# frozen_string_literal: true

class Whatsapp::ReengagementTemplateNameService
  REENGAGEMENT_BASE_NAME = 'proactive_reengagement'

  def self.reengagement_template_name(inbox_id, version = nil)
    base_name = reengagement_base_name_for_inbox(inbox_id)
    version ? "#{base_name}_#{version}" : base_name
  end

  def self.extract_version(template_name, inbox_id)
    return nil if template_name.blank?

    pattern = versioned_pattern_for_inbox(inbox_id)
    match = template_name.match(pattern)
    match ? match[1].to_i : nil
  end

  def self.generate_next_template_name(base_name, inbox_id, current_template_name)
    return base_name if current_template_name.blank?

    current_version = extract_version(current_template_name, inbox_id)
    next_version = current_version ? current_version + 1 : 1
    reengagement_template_name(inbox_id, next_version)
  end

  def self.reengagement_base_name_for_inbox(inbox_id)
    "#{REENGAGEMENT_BASE_NAME}_#{inbox_id}"
  end

  def self.base_pattern_for_inbox(inbox_id)
    /^#{REENGAGEMENT_BASE_NAME}_#{inbox_id}$/
  end

  def self.versioned_pattern_for_inbox(inbox_id)
    /^#{REENGAGEMENT_BASE_NAME}_#{inbox_id}_(\d+)$/
  end

  private_class_method :reengagement_base_name_for_inbox, :base_pattern_for_inbox, :versioned_pattern_for_inbox
end
