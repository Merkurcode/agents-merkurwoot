# == Schema Information
#
# Table name: conversation_ai_usages
#
#  id                   :bigint           not null, primary key
#  thread_id            :string           not null
#  ai_cost_usd          :decimal(10, 6)
#  ai_input_tokens      :integer          default(0)
#  ai_output_tokens     :integer          default(0)
#  ai_llm_calls         :integer          default(0)
#  ai_graph_invocations :integer          default(0)
#  ai_avg_latency_ms    :float
#  ai_p95_latency_ms    :float
#  ai_error_count       :integer          default(0)
#  ai_duration_seconds  :float
#  ai_started_at        :datetime
#  ai_models_used       :string
#  ai_cost_by_model     :jsonb            default({})
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  conversation_id      :bigint           not null
#  account_id           :bigint           not null
#

class ConversationAiUsage < ApplicationRecord
  belongs_to :conversation
  belongs_to :account

  validates :thread_id, :ai_started_at, presence: true
  validates :conversation_id, uniqueness: true
end
