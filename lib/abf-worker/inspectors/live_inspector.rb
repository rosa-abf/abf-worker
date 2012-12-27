require 'time'

module AbfWorker
  module Inspectors
    class LiveInspector
      CHECK_INTERVAL = 60 # 60 sec

      def initialize(worker, time_living)
        @worker       = worker
        @build_id     = @worker.build_id
        @worker_id    = @worker.worker_id
        @kill_at      = Time.now + time_living.to_i
        @logger       = @worker.logger
      end

      def run
        @thread = Thread.new do
          while true
            begin
              sleep CHECK_INTERVAL
              stop_build if kill_now?
            rescue => e
            end
          end
        end
      end

      private

      def kill_now?
        if @kill_at < Time.now
          @logger.info '===> Time expired, VM will be stopped...'
          return true
        end
        if status == 'USR1'
          @logger.info '===> Received signal to stop VM...'
          true
        else
          false
        end
      end

      def stop_build
        @worker.status = AbfWorker::BaseWorker::BUILD_CANCELED
        # Immediately kill child but don't exit
        # Process.kill('USR1', @worker_id)
        runner = @worker.runner
        runner.can_run = false
        runner.script_runner.kill if runner.script_runner
        runner.rollback if runner.respond_to?(:rollback)
      end

      def status
        return nil if @worker.is_a?(AbfWorker::PublishBuildListContainerBaseWorker)
        q = 'abfworker::'
        q << (@worker.is_a?(AbfWorker::IsoWorker) ? 'iso' : 'rpm')
        q << '-worker-'
        q << @worker.build_id.to_s
        q << '::live-inspector'
        Resque.redis.get(q)
      end

    end
  end
end