require 'time'

module AbfWorker
  module Inspectors
    class LiveInspector
      CHECK_INTERVAL = 60 # 60 sec

      def initialize(build_id, worker_id, time_living)
        @build_id   = build_id
        @worker_id  = worker_id
        @kill_at    = Time.now + (time_living.to_i * 60)
        init_thread
      end


      private

      def init_thread
        @thread = Thread.new do
          while true
            sleep CHECK_INTERVAL
            if kill_now?
              # Immediately kill child but don't exit
              Process.kill('USR1', @worker_id)
              return
            end
          end
        end
        @thread.run
      end

      def kill_now?
        return true if @kill_at < Time.now
        status = Resque.redis.get("abfworker::iso-worker-#{@build_id}::live-inspector")
        status == 'USR1' ? true : false
      end

    end
  end
end