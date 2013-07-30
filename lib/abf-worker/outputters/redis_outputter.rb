require 'log4r/outputter/outputter'

module AbfWorker::Outputters
  class RedisOutputter < Log4r::Outputter
    REDIS_HOST = APP_CONFIG['redis_outputter_server'].gsub(/\:.*$/, '')
    REDIS_PORT = APP_CONFIG['redis_outputter_server'].gsub(/.*\:/, '')

    def initialize(name, hash={})
      super(name, hash)
      @name = name
      @worker = hash[:worker]
      @buffer = []
      @buffer_limit   = hash[:buffer_limit] || 100
      @time_interval  = hash[:time_interval] || 10
      init_thread
    end


    private

    # perform the write
    def write(data)
      line = data.to_s
      unless line.empty?
        last_line = @buffer.last
        if last_line && (line.strip =~ /^[\#]+$/) && (line[-1, 1] == last_line[-1, 1])
          last_line.rstrip!
          last_line << line.lstrip
        else
          @buffer.shift if @buffer.size > @buffer_limit
          @buffer << line
        end
      end
    end

    def init_thread
      @thread = Thread.new do
        while true
          sleep @time_interval
          redis.setex(@name, (@time_interval + 5), @buffer.join) rescue @redis = nil
        end # while
      end
      @thread.run
    end

    def redis
      @redis ||= Redis.new host: REDIS_HOST, port: REDIS_PORT, driver: :hiredis
    end

  end
end