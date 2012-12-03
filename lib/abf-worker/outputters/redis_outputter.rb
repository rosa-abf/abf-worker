require 'log4r/outputter/outputter'

module AbfWorker
  module Outputters
    class RedisOutputter < Log4r::Outputter

      def initialize(name, hash={})
        super(name, hash)
        @worker = hash[:worker]
        @buffer = []
        @buffer_limit = hash[:buffer_limit] || 100
        @time_interval = hash[:time_interval] || 10
        @line_number = 1
        init_thread
      end


      private

      # perform the write
      def write(data)
        line = data.to_s#.gsub(/^.*(worker\-[\d]+\:)/, '')
        unless line.empty?
          last_line = @buffer.last
          if last_line && (line.strip =~ /^[\#]+$/) && (line[-1, 1] == last_line[-1, 1])
            last_line.rstrip!
            last_line << line.lstrip
          else
            l = @line_number.to_s
            l << ': '
            l << line
            @line_number += 1
            @buffer.shift if @buffer.size > @buffer_limit
            @buffer << l
          end
        end
      end

      def init_thread
        @thread = Thread.new do
          while true
            begin
              sleep @time_interval
              Resque.redis.setex(
                @name,
                (@time_interval + 5),
                @buffer.join
              )
            rescue => e
              @worker.logger.error e.message
              @worker.logger.error e.backtrace.join("\n")
            end # while
          end
        end
        @thread.run
      end

    end
  end
end