# == Schema Information
#
# Table name: product_blueprints
#
#  id                         :bigint           not null, primary key
#  buyer_persona              :jsonb
#  external_id                :string
#  extra_sections             :jsonb
#  name                       :string           not null
#  perfil_producto            :jsonb
#  resumen_agente             :jsonb
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  account_id                 :bigint           not null
#  bulk_processing_request_id :bigint
#  last_updated_by_id         :bigint
#  user_id                    :bigint
#
# Indexes
#
#  index_product_blueprints_on_account_id                  (account_id)
#  index_product_blueprints_on_account_id_and_name         (account_id,name) UNIQUE
#  index_product_blueprints_on_bulk_processing_request_id  (bulk_processing_request_id)
#  index_product_blueprints_on_last_updated_by_id          (last_updated_by_id)
#  index_product_blueprints_on_resumen_agente              (resumen_agente) USING gin WHERE (resumen_agente IS NOT NULL)
#  index_product_blueprints_on_user_id                     (user_id)
#
class ProductBlueprint < ApplicationRecord
  belongs_to :account
  belongs_to :bulk_processing_request, optional: true
  belongs_to :user, optional: true
  belongs_to :last_updated_by, class_name: 'User', optional: true

  validates :name, presence: true, uniqueness: { scope: :account_id }

  scope :by_exact_name, ->(name) { where(name: name) }
  scope :for_account, ->(account_id) { where(account_id: account_id) }
end
