class AddImportFormatToBulkProcessingRequests < ActiveRecord::Migration[7.0]
  def change
    add_column :bulk_processing_requests, :import_format, :string, null: false, default: 'excel_sku'
  end
end
