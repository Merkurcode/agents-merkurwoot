# == Schema Information
#
# Table name: pipeline_statuses
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_pipeline_statuses_on_account_id           (account_id)
#  index_pipeline_statuses_on_account_id_and_name  (account_id,name) UNIQUE
#
class PipelineStatus < ApplicationRecord
  # == Constants ============================================================
  DEFAULT_STATUSES = %w[new contacted qualified 'proposal send' close].freeze

  # == Extensions ===========================================================
  # == Enums ================================================================
  # == Validations ===========================================================
  validates :name, presence: true, uniqueness: { scope: :account_id }

  # == Callbacks =====================================================
  before_save :set_name

  # == Attributes ===========================================================
  # == Relationships ========================================================
  belongs_to :account
  has_many :conversations, dependent: :nullify

  # == Instance Methods =====================================================

  private

  def set_name
    self.name = name.downcase
  end
end
