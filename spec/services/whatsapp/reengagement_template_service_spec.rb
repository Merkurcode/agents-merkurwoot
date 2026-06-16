require 'rails_helper'

RSpec.describe Whatsapp::ReengagementTemplateService do
  let(:account) { create(:account) }
  let(:whatsapp_channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
  end
  let(:inbox) { create(:inbox, channel: whatsapp_channel, account: account) }
  let(:service) { described_class.new(whatsapp_channel) }
  let(:base_template_name) { "proactive_reengagement_#{inbox.id}" }

  let(:template_config) do
    {
      message: 'Hola {{1}}, ¿en qué podemos ayudarte hoy?',
      language: 'es_MX',
      template_name: base_template_name
    }
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('WHATSAPP_CLOUD_BASE_URL', anything).and_return('https://graph.facebook.com')
  end

  describe '#create_template' do
    context 'when Meta API returns success' do
      before do
        stub_request(:post, /graph.facebook.com.*message_templates/)
          .to_return(
            status: 200,
            body: { id: '123456', name: base_template_name, status: 'PENDING' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns success with template details' do
        result = service.create_template(template_config)

        expect(result[:success]).to be true
        expect(result[:template_name]).to eq(base_template_name)
        expect(result[:template_id]).to eq('123456')
        expect(result[:status]).to eq('PENDING')
        expect(result[:language]).to eq('es_MX')
      end

      it 'sends BODY-only component (no buttons)' do
        stub_request(:post, /graph.facebook.com.*message_templates/)
          .with { |req|
            body = JSON.parse(req.body)
            components = body['components']
            components.length == 1 && components.first['type'] == 'BODY'
          }
          .to_return(
            status: 200,
            body: { id: '123', name: base_template_name }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        service.create_template(template_config)
      end

      it 'uses MARKETING category' do
        stub_request(:post, /graph.facebook.com.*message_templates/)
          .with { |req|
            JSON.parse(req.body)['category'] == 'MARKETING'
          }
          .to_return(
            status: 200,
            body: { id: '123', name: base_template_name }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        service.create_template(template_config)
      end
    end

    context 'when Meta API returns error' do
      before do
        stub_request(:post, /graph.facebook.com.*message_templates/)
          .to_return(
            status: 400,
            body: { error: { message: 'Invalid parameter', code: 100 } }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns failure result' do
        result = service.create_template(template_config)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Template creation failed')
      end
    end
  end

  describe '#get_template_status' do
    context 'when template exists in Meta' do
      before do
        stub_request(:get, /graph.facebook.com.*message_templates.*proactive_reengagement/)
          .to_return(
            status: 200,
            body: {
              data: [{ id: '999', name: base_template_name, status: 'APPROVED', language: 'es_MX' }]
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns success with template details' do
        result = service.get_template_status(base_template_name)

        expect(result[:success]).to be true
        expect(result[:template][:status]).to eq('APPROVED')
        expect(result[:template][:name]).to eq(base_template_name)
      end
    end

    context 'when template does not exist in Meta' do
      before do
        stub_request(:get, /graph.facebook.com.*message_templates/)
          .to_return(
            status: 200,
            body: { data: [] }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns failure' do
        result = service.get_template_status(base_template_name)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Template not found')
      end
    end
  end

  describe '#delete_template' do
    context 'when deletion succeeds' do
      before do
        stub_request(:delete, /graph.facebook.com.*message_templates/)
          .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns success' do
        result = service.delete_template(base_template_name)

        expect(result[:success]).to be true
      end
    end
  end
end
