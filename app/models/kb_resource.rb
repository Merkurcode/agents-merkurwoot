class KbResource < ApplicationRecord
  include Events::Types

  MAX_FILE_SIZE = 100.megabytes
  MAX_STORAGE_PER_ACCOUNT = 2.gigabytes

  # Security limits
  MAX_NAME_LENGTH = 255
  MAX_DESCRIPTION_LENGTH = 1000
  MAX_FOLDER_PATH_LENGTH = 500

  # Dangerous patterns for path traversal and injection
  DANGEROUS_PATTERNS = [
    '..', # Path traversal
    '<script', # XSS
    'javascript:', # XSS
    "\x00", # Null byte injection
    "\r", "\n" # CRLF injection
  ].freeze

  belongs_to :account
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :updated_by, class_name: 'User', optional: true

  has_many :kb_resource_product_catalogs, dependent: :destroy
  has_many :product_catalogs, through: :kb_resource_product_catalogs

  validates :name, presence: true,
                   length: { maximum: MAX_NAME_LENGTH, message: "cannot exceed #{MAX_NAME_LENGTH} characters" }
  validates :description, length: { maximum: MAX_DESCRIPTION_LENGTH, message: "cannot exceed #{MAX_DESCRIPTION_LENGTH} characters" },
                          allow_blank: true
  validates :folder_path, length: { maximum: MAX_FOLDER_PATH_LENGTH, message: "cannot exceed #{MAX_FOLDER_PATH_LENGTH} characters" },
                          allow_blank: true
  validates :file_name, presence: true
  validates :s3_key, presence: true, uniqueness: true
  validate :validate_file_size, on: :create
  validate :validate_storage_limit, on: :create
  validate :validate_name_security
  validate :validate_description_security
  validate :validate_folder_path_security

  before_validation :sanitize_inputs

  scope :visible, -> { where(is_visible: true) }
  scope :ordered, -> { order(created_at: :desc) }

  after_create_commit :dispatch_create_event
  after_update_commit :dispatch_update_event
  after_destroy_commit :dispatch_destroy_event

  def presigned_url
    KbResources::PresignedUrlService.new.generate_url(s3_key)
  end

  # Returns total storage used by account in bytes
  def self.storage_used_by_account(account_id)
    where(account_id: account_id).sum(:file_size) || 0
  end

  # Returns remaining storage available for account in bytes
  def self.storage_remaining_for_account(account_id)
    MAX_STORAGE_PER_ACCOUNT - storage_used_by_account(account_id)
  end

  private

  def sanitize_inputs
    self.name = name&.strip&.gsub(/[<>]/, '')
    self.description = description&.strip
  end

  def validate_file_size
    return if file_size.blank?
    return unless file_size > MAX_FILE_SIZE

    errors.add(:file_size, "exceeds maximum allowed size of #{MAX_FILE_SIZE / 1.megabyte}MB")
  end

  def validate_storage_limit
    return if account_id.blank? || file_size.blank?

    current_storage = KbResource.storage_used_by_account(account_id)
    new_total = current_storage + file_size

    return unless new_total > MAX_STORAGE_PER_ACCOUNT

    errors.add(:file_size, "would exceed account storage limit of #{MAX_STORAGE_PER_ACCOUNT / 1.gigabyte}GB")
  end

  def validate_name_security
    return if name.blank?

    DANGEROUS_PATTERNS.each do |pattern|
      if name.downcase.include?(pattern.downcase)
        errors.add(:name, 'contains invalid characters')
        break
      end
    end
  end

  def validate_description_security
    return if description.blank?

    DANGEROUS_PATTERNS.each do |pattern|
      if description.downcase.include?(pattern.downcase)
        errors.add(:description, 'contains invalid characters')
        break
      end
    end
  end

  def validate_folder_path_security
    return if folder_path.blank?

    if folder_path.include?('..')
      errors.add(:folder_path, 'contains invalid path traversal characters')
      return
    end

    # Ensure folder path starts with /
    unless folder_path.start_with?('/')
      errors.add(:folder_path, 'must start with /')
    end
  end

  def resource_payload
    {
      id: id,
      name: name,
      s3_url: presigned_url,
      product_catalog_ids: product_catalog_ids
    }
  end

  def dispatch_resource_event(action:, resource_data:)
    Rails.configuration.dispatcher.dispatch(
      KB_RESOURCE_UPDATED,
      Time.zone.now,
      account: account,
      action: action,
      resource: resource_data
    )
  end

  def dispatch_create_event
    dispatch_resource_event(action: 'created', resource_data: resource_payload)
  end

  def dispatch_update_event
    dispatch_resource_event(action: 'updated', resource_data: resource_payload)
  end

  def dispatch_destroy_event
    dispatch_resource_event(action: 'deleted', resource_data: { id: id, name: name })
  end
end
