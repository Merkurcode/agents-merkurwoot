class FaqItem < ApplicationRecord
  include Events::Types

  belongs_to :account
  belongs_to :faq_category, optional: true
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :updated_by, class_name: 'User', optional: true

  validate :has_at_least_one_translation

  # Skip callbacks for bulk operations (handled separately in controllers)
  attr_accessor :skip_catalog_callbacks

  before_destroy :cache_destroy_data
  after_create_commit :dispatch_create_event, unless: :skip_catalog_callbacks
  after_update_commit :dispatch_update_event, unless: :skip_catalog_callbacks
  after_destroy_commit :dispatch_destroy_event, unless: :skip_catalog_callbacks

  scope :ordered, -> { order(position: :asc, created_at: :asc) }
  scope :visible, -> { where(is_visible: true) }
  scope :for_category, ->(category_id) { where(faq_category_id: category_id) }

  # Helper methods for translations
  def question(locale = 'es')
    translations.dig(locale.to_s, 'question') || translations.dig('en', 'question')
  end

  def answer(locale = 'es')
    translations.dig(locale.to_s, 'answer') || translations.dig('en', 'answer')
  end

  def available_locales
    translations.keys
  end

  private

  def has_at_least_one_translation
    return if translations.present? && translations.values.any? { |t| t['question'].present? }

    errors.add(:translations, 'must have at least one question')
  end

  def cache_destroy_data
    @cached_destroy_data = {
      id: id,
      faq_category_id: faq_category_id,
      account: account
    }
  end

  def dispatch_create_event
    Rails.configuration.dispatcher.dispatch(
      FAQ_CATALOG_UPDATED,
      Time.zone.now,
      account: account,
      added_count: 1,
      updated_count: 0,
      deleted_count: 0,
      added_faq_items: [{ id: id, faq_category_id: faq_category_id }],
      updated_faq_items: [],
      deleted_faq_items: []
    )
  end

  def dispatch_update_event
    Rails.configuration.dispatcher.dispatch(
      FAQ_CATALOG_UPDATED,
      Time.zone.now,
      account: account,
      added_count: 0,
      updated_count: 1,
      deleted_count: 0,
      added_faq_items: [],
      updated_faq_items: [{ id: id, faq_category_id: faq_category_id }],
      deleted_faq_items: []
    )
  end

  def dispatch_destroy_event
    Rails.configuration.dispatcher.dispatch(
      FAQ_CATALOG_UPDATED,
      Time.zone.now,
      account: @cached_destroy_data[:account],
      added_count: 0,
      updated_count: 0,
      deleted_count: 1,
      added_faq_items: [],
      updated_faq_items: [],
      deleted_faq_items: [{ id: @cached_destroy_data[:id], faq_category_id: @cached_destroy_data[:faq_category_id] }]
    )
  end
end
