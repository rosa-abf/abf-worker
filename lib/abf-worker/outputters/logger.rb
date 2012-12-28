require 'log4r'

module AbfWorker
  module Outputters
    class Logger < Log4r::Logger

      def i(message, prefix = '==>', add_timestamp = true)
        m = prefix
        m << " [#{Time.now.utc}] " if add_timestamp
        m << message
        info m
      end

    end
  end
end