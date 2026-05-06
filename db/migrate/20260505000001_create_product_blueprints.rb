class CreateProductBlueprints < ActiveRecord::Migration[7.0]
  def change
    create_table :product_blueprints do |t|
      t.references :account, null: false, foreign_key: true
      t.references :bulk_processing_request, foreign_key: true
      t.references :user, foreign_key: true
      t.references :last_updated_by, foreign_key: { to_table: :users }

      t.string :name, null: false
      t.string :external_id

      t.jsonb :resumen_agente
      t.jsonb :perfil_producto
      t.jsonb :buyer_persona
      t.jsonb :extra_sections

      t.timestamps
    end

    add_index :product_blueprints, [:account_id, :name], unique: true
    add_index :product_blueprints, :resumen_agente, using: :gin, where: 'resumen_agente IS NOT NULL'
  end
end
