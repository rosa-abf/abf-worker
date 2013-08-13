require 'api_smith'

module AbfWorker::Models
  class Base
    include ::APISmith::Client

    base_uri APP_CONFIG['abf_api']['url']
    basic_auth APP_CONFIG['abf_api']['token'], ''
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
      AbfWorker::BaseWorker.logger.log "Rosa-Build API Request: #{method.to_s.upcase} #{full_path} (#{options_str})"
      yield if block_given? # this is where the request is sent
    end # instrument_request

  end
end