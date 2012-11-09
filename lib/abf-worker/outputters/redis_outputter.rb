require 'log4r/outputter/outputter'

module AbfWorker
  module Outputters
    class RedisOutputter < Log4r::Outputter

      def initialize(name, buffer_limit = 100, time_interval = 10, hash={})
        super(name, hash)
        @buffer = []
        @buffer_limit = buffer_limit
        @time_interval = time_interval
        @line_number = 1
        init_thread
      end


      private

      # perform the write
      def write(data)
        @buffer.shift if @buffer.size > @buffer_limit
        line = data.to_s.gsub(/^.*\:{1}/, '')
        unless line.empty?
          l = @line_number.to_s
          l << ': '
          l << line
          @buffer << l
          @line_number += 1
        end
      end

      def init_thread
        @thread = Thread.new do
          while true
            sleep @time_interval
            Resque.redis.setex(
              @name,
              (@time_interval + 5),
              @buffer.join
            )
          end
        end
        @thread.run
      end

    end
  end
end