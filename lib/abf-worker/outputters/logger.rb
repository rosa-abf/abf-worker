require 'log4r'

module AbfWorker
  module Outputters
    class Logger < Log4r::Logger
      FILTER = [/\:\/\/.*\:\@/, '://[FILTERED]@']

      def log(message, prefix = '==>', add_timestamp = true)
        m = prefix
        m << " [#{Time.now.utc}] " if add_timestamp
        m << message.gsub(*FILTER)
        info m
      end

    end
  end
end