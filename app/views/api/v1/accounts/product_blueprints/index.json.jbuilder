json.data @blueprints do |blueprint|
  json.id blueprint.id
  json.name blueprint.name
  json.external_id blueprint.external_id
  json.product_catalog_id @product_catalog_ids[blueprint.name]
  json.resumen_agente blueprint.resumen_agente
  json.created_at blueprint.created_at
  json.updated_at blueprint.updated_at
end

json.meta do
  json.current_page @current_page
  json.total_pages @total_pages
  json.total_count @total_count
  json.per_page (params[:per_page] || 50).to_i
end
