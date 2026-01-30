# frozen_string_literal: true

module Crm
  module Zoho
    class TokenRefresher
      OAUTH_TOKEN_URL = 'https://accounts.zoho.com/oauth/v2/token'

      # Scopes necesarios para Zoho CRM
      DEFAULT_SCOPES = [
        'ZohoCRM.org.ALL',
        'ZohoCRM.settings.ALL',
        'ZohoCRM.users.ALL',
        'ZohoCRM.templates.email.READ',
        'ZohoCRM.templates.inventory.READ',
        'ZohoCRM.modules.ALL'
      ].freeze

      def initialize(hook)
        @hook = hook
        @credentials = hook.credentials
      end

      def refresh!
        response = HTTParty.post(
          OAUTH_TOKEN_URL,
          query: build_query_params,
          headers: { 'Content-Type' => 'application/x-www-form-urlencoded' }
        )

        unless response.success?
          Rails.logger.error "Zoho token refresh failed: #{response.code} - #{response.body}"
          raise "Token refresh failed: #{response.body}"
        end

        data = response.parsed_response

        {
          'access_token' => data['access_token'],
          'expires_in' => data['expires_in'], # 3600 segundos (1 hora)
          'api_domain' => data['api_domain'],
          'token_type' => data['token_type'] || 'Bearer'
        }
      end

      private

      def build_query_params
        {
          client_id: client_id,
          client_secret: client_secret,
          grant_type: 'client_credentials',
          scope: scope_string,
          soid: soid
        }
      end

      def scope_string
        # Usar scopes personalizados si están configurados, sino usar los default
        scopes = @credentials['scopes'] || DEFAULT_SCOPES
        scopes.join(',')
      end

      private

      def client_id
        @credentials['client_id'] || @credentials.dig('credentials', 'client_id')
      end

      def client_secret
        @credentials['client_secret'] || @credentials.dig('credentials', 'client_secret')
      end

      def soid
        @credentials['soid'] || @credentials.dig('credentials', 'soid')
      end
    end
  end
end
