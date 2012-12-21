require 'api_smith'

module AbfWorker
  module Models
    class Base
      include ::APISmith::Client

      ROOT_PATH = File.dirname(__FILE__).to_s << '/../../../'
      API_CONFIG = ROOT_PATH + 'config/file-store.yml'

      def self.api_token
        return @api_token if @api_token
        api_config = YAML.load_file(API_CONFIG)
        @api_token = api_config["server_1"]
        @api_token
      end

      base_uri 'https://abf.rosalinux.ru/api/v1'
      basic_auth self.api_token, ''
      # Timeout for opening connection and reading data.
      default_timeout 1

      format :json

      def base_query_options
        { :format => 'json' }
      end

      # Override method in superclass to log request to def logger.
      def instrument_request(method, full_path, options)
        extra_query = options[:extra_query] || {}
        options_str = extra_query.map { |k,v| "#{k}: #{v}" }.join(', ')
        AbfWorker::BaseWorker.logger.info "==> Rosa-Build API Request: #{method.to_s.upcase} #{full_path} (#{options_str})"
        yield if block_given? # this is where the request is sent
      end # instrument_request

    end
  end
end