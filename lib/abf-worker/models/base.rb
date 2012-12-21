module AbfWorker
  module Models
    class Base
      include APISmith::Client

      ROOT_PATH = File.dirname(__FILE__).to_s << '/../../../'
      API_CONFIG = ROOT_PATH + 'config/file-store.yml'

      base_uri 'https://abf.rosalinux.ru/api/v1'
      basic_auth self.api_token, ''
      # Timeout for opening connection and reading data.
      default_timeout 1

      format :json

      def base_query_options
        { :format => 'json' }
      end

      private

      def self.api_token
        return @api_token if @api_token
        api_config = YAML.load_file(API_CONFIG)
        @api_token = api_config["server_1"]
        @api_token
      end

    end
  end
end