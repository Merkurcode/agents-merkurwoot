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
#  index_pipeline_statuses_on_account_id  (account_id)
#
class PipelineStatus < ApplicationRecord
  # == Constants ============================================================
  # == Extensions ===========================================================
  # == Enums ================================================================
  # == Validations ===========================================================
  validates :name, presence: true

  # == Callbacks =====================================================
  before_save :set_name

  # == Attributes ===========================================================
  # == Relationships ========================================================
  belongs_to :account

  # == Instance Methods =====================================================

  private

  def set_name
    self.name = name.downcase
  end
end
