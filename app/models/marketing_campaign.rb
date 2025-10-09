# == Schema Information
#
# Table name: marketing_campaigns
#
#  id          :bigint           not null, primary key
#  active      :boolean          default(TRUE), not null
#  description :text             default("")
#  end_date    :date             not null
#  start_date  :date             not null
#  title       :string           default(""), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#  source_id   :string           default("")
#
# Indexes
#
#  index_marketing_campaigns_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class MarketingCampaign < ApplicationRecord
  belongs_to :account

  validates :title, presence: true
  validates :start_date, :end_date, presence: true

  scope :active, -> { where(active: true) }
end
