class CreateConversationAiUsages < ActiveRecord::Migration[7.0]
  def change
    create_table :conversation_ai_usages do |t|
      t.references :conversation, null: false, index: { unique: true }
      t.references :account,      null: false, index: true
      t.string  :thread_id,            null: false
      t.decimal :ai_cost_usd,          precision: 10, scale: 6
      t.integer :ai_input_tokens,      default: 0
      t.integer :ai_output_tokens,     default: 0
      t.integer :ai_llm_calls,         default: 0
      t.integer :ai_graph_invocations, default: 0
      t.float   :ai_avg_latency_ms
      t.float   :ai_p95_latency_ms
      t.integer :ai_error_count,       default: 0
      t.float   :ai_duration_seconds
      t.datetime :ai_started_at
      t.string  :ai_models_used
      t.jsonb   :ai_cost_by_model,     default: {}
      t.timestamps
    end

    add_index :conversation_ai_usages, :thread_id
    add_index :conversation_ai_usages, [:account_id, :created_at]
  end
end
