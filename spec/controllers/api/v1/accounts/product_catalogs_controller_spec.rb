require 'rails_helper'

RSpec.describe 'Product Catalogs API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:product) { create(:product_catalog, account: account) }

  before do
    allow_any_instance_of(ProductCatalogs::S3CleanupService).to receive(:delete_product_folder)
    allow_any_instance_of(ProductCatalogs::S3CleanupService).to receive(:delete_file)
    allow_any_instance_of(ProductCatalogs::PresignedUrlService).to receive(:generate_url).and_return('https://s3.example.com/presigned')
  end

  describe 'GET /api/v1/accounts/:account_id/product_catalogs' do
    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/product_catalogs"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as agent' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/product_catalogs",
            headers: agent.create_new_auth_token, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as admin' do
      it 'returns paginated products' do
        get "/api/v1/accounts/#{account.id}/product_catalogs",
            headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        body = response.parsed_body
        expect(body['data'].length).to eq(1)
        expect(body['meta']['total_count']).to eq(1)
      end

      it 'filters products by search query' do
        create(:product_catalog, account: account, productName: 'Unrelated Widget')
        get "/api/v1/accounts/#{account.id}/product_catalogs",
            params: { q: product.productName },
            headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['data'].map { |p| p['productName'] }).to include(product.productName)
      end
    end
  end

  describe 'GET /api/v1/accounts/:account_id/product_catalogs/:id' do
    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/product_catalogs/#{product.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as admin' do
      it 'returns the product with its attributes' do
        get "/api/v1/accounts/#{account.id}/product_catalogs/#{product.id}",
            headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        body = response.parsed_body
        expect(body['productName']).to eq(product.productName)
        expect(body['industry']).to eq(product.industry)
        expect(body['listPrice']).to eq(product.listPrice.to_s)
      end
    end
  end

  describe 'PATCH /api/v1/accounts/:account_id/product_catalogs/:id' do
    context 'when unauthenticated' do
      it 'returns unauthorized' do
        patch "/api/v1/accounts/#{account.id}/product_catalogs/#{product.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as agent' do
      it 'returns unauthorized' do
        patch "/api/v1/accounts/#{account.id}/product_catalogs/#{product.id}",
              params: { product_catalog: { productName: 'New Name' } },
              headers: agent.create_new_auth_token, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as admin' do
      it 'updates productName' do
        patch "/api/v1/accounts/#{account.id}/product_catalogs/#{product.id}",
              params: { product_catalog: { productName: 'Updated Product' } },
              headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        expect(product.reload.productName).to eq('Updated Product')
      end

      it 'updates listPrice' do
        patch "/api/v1/accounts/#{account.id}/product_catalogs/#{product.id}",
              params: { product_catalog: { listPrice: 199.99 } },
              headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        expect(product.reload.listPrice).to eq(199.99)
      end

      it 'updates industry, type and description' do
        patch "/api/v1/accounts/#{account.id}/product_catalogs/#{product.id}",
              params: { product_catalog: { industry: 'Finance', type: 'Service', description: 'New desc' } },
              headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        reloaded = product.reload
        expect(reloaded.industry).to eq('Finance')
        expect(reloaded.type).to eq('Service')
        expect(reloaded.description).to eq('New desc')
      end

      it 'sets last_updated_by_id to the current user' do
        patch "/api/v1/accounts/#{account.id}/product_catalogs/#{product.id}",
              params: { product_catalog: { productName: 'Changed' } },
              headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        expect(product.reload.last_updated_by_id).to eq(admin.id)
      end

      context 'when removed_media_ids is provided' do
        let!(:media) { create(:product_medium, product_catalog: product) }

        it 'destroys the specified media records' do
          patch "/api/v1/accounts/#{account.id}/product_catalogs/#{product.id}",
                params: { product_catalog: { productName: product.productName }, removed_media_ids: [media.id] },
                headers: admin.create_new_auth_token, as: :json

          expect(response).to have_http_status(:success)
          expect(ProductMedium.exists?(media.id)).to be(false)
        end

        it 'does not destroy media belonging to other products' do
          other_product = create(:product_catalog, account: account)
          other_media = create(:product_medium, product_catalog: other_product)

          patch "/api/v1/accounts/#{account.id}/product_catalogs/#{product.id}",
                params: { product_catalog: { productName: product.productName }, removed_media_ids: [other_media.id] },
                headers: admin.create_new_auth_token, as: :json

          expect(response).to have_http_status(:success)
          expect(ProductMedium.exists?(other_media.id)).to be(true)
        end
      end

      context 'when new_media files are provided' do
        it 'uploads files to S3 and creates ProductMedium records' do
          allow_any_instance_of(Aws::S3::Client).to receive(:put_object).and_return(true)

          file = fixture_file_upload(
            Rails.root.join('spec/fixtures/files/sample.png'),
            'image/png'
          )

          expect do
            patch "/api/v1/accounts/#{account.id}/product_catalogs/#{product.id}",
                  params: { product_catalog: { productName: product.productName }, new_media: [file] },
                  headers: admin.create_new_auth_token
          end.to change(ProductMedium, :count).by(1)

          expect(response).to have_http_status(:success)
          media = product.all_product_media.last
          expect(media.file_type).to eq('image')
          expect(media.s3_status).to eq('completed')
          expect(media.user_id).to eq(admin.id)
        end
      end
    end
  end

  describe 'DELETE /api/v1/accounts/:account_id/product_catalogs/:id' do
    context 'when unauthenticated' do
      it 'returns unauthorized' do
        delete "/api/v1/accounts/#{account.id}/product_catalogs/#{product.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as admin' do
      it 'destroys the product' do
        expect do
          delete "/api/v1/accounts/#{account.id}/product_catalogs/#{product.id}",
                 headers: admin.create_new_auth_token, as: :json
        end.to change(ProductCatalog, :count).by(-1)

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'POST /api/v1/accounts/:account_id/product_catalogs/:id/toggle_visibility' do
    context 'when authenticated as admin' do
      it 'toggles visibility from true to false' do
        product.update!(is_visible: true)

        post "/api/v1/accounts/#{account.id}/product_catalogs/#{product.id}/toggle_visibility",
             headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        expect(product.reload.is_visible).to be(false)
      end

      it 'toggles visibility from false to true' do
        product.update!(is_visible: false)

        post "/api/v1/accounts/#{account.id}/product_catalogs/#{product.id}/toggle_visibility",
             headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        expect(product.reload.is_visible).to be(true)
      end
    end
  end
end
