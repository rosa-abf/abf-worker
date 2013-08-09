require 'vagrant'
require 'sahara'
require 'sahara/command/vagrant'
require 'net/ssh'
require 'abf-worker/exceptions/script_error'
require 'abf-worker/runners/vm'
require 'abf-worker/outputters/logger'
require 'abf-worker/outputters/redis_outputter'
require 'socket'

module AbfWorker
  class BaseWorker
    include Log4r

    BUILD_COMPLETED = 0
    BUILD_FAILED    = 1
    BUILD_PENDING   = 2
    BUILD_STARTED   = 3
    BUILD_CANCELED  = 4
    TESTS_FAILED    = 5

    class << self
      attr_accessor :status,
                    :build_id,
                    :worker_id,
                    :tmp_dir,
                    :vm,
                    :live_inspector,
                    :logger_name

      def perform(options)
        initialize options
        @vm.initialize_vagrant_env
        @vm.start_vm
        @runner.run_script
        @vm.rollback_and_halt_vm { send_results }
      rescue Resque::TermException, AbfWorker::Exceptions::ScriptError, Vagrant::Errors::VagrantError => e
        if @task_restarted
          print_error(e)
          @status = BUILD_FAILED if @status != BUILD_CANCELED
          @vm.clean { send_results }
        else
          @vm.clean
          system "rm -rf #{@vm.results_folder}"
          system "rm -f #{ROOT}/log/#{@logger_name}.log" if @logger_name
          restart_task
        end
      rescue => e
        @status = BUILD_FAILED if @status != BUILD_CANCELED
        print_error(e, true)
        @vm.rollback_and_halt_vm { send_results }
      end

      def print_error(e, force = false)
        begin
          vm_id = @vm.get_vm.id
        rescue => ex
          vm_id = nil
        end

        Airbrake.notify(
          e,
          :parameters => {
            :hostname   => Socket.gethostname,
            :worker_id  => @worker_id,
            :vm_id      => vm_id,
            :options    => @options
          }
        ) if (@task_restarted || force) && ENV['ENV'] == 'production'

        a = []
        a << '==> ABF-WORKER-ERROR-START'
        a << 'Something went wrong, report has been sent to ABF team, please try again.'
        a << 'If this error will be happen again, please inform us using https://abf.rosalinux.ru/contact'
        a << '----------'
        a << e.message.gsub(*AbfWorker::Outputters::Logger::FILTER)
        a << e.backtrace.join("\n")
        a << '<== ABF-WORKER-ERROR-END'
        logger.error a.join("\n")
      end

      protected

      def restart_task
        redis = Resque.redis
        @options['extra'] ||= {}
        @options['extra']['task_restarted'] = true
        redis.lpush "queue:#{@queue}", {
          :class => name,
          :args  => [@options]
        }.to_json
      end

      def initialize_live_inspector(time_living)
        @live_inspector = AbfWorker::Inspectors::LiveInspector.new(self, time_living)
        @live_inspector.run
      end

      def initialize(options)
        @options = options
        @extra = options['extra'] || {}
        @task_restarted = @extra['task_restarted'] ? true : false
        @skip_feedback = options['skip_feedback'] || false
        @status = BUILD_STARTED
        @build_id = options['id']
        @worker_id = Process.ppid
        init_tmp_folder
        update_build_status_on_abf
        # @vm = Runners::Vm.new(self, options['distrib_type'], options['arch'])
        @vm = AbfWorker::Runners::Vm.new(self, options['platform'])
      end

      def init_logger(logger_name = nil)
        @logger_name = logger_name
        @logger = AbfWorker::Outputters::Logger.new @logger_name, Log4r::ALL
        @logger.outputters << Log4r::Outputter.stdout

        # see: https://github.com/colbygk/log4r/blob/master/lib/log4r/formatter/patternformatter.rb#L22
        formatter = Log4r::PatternFormatter.new(:pattern => "%m")
        unless @skip_feedback
          @logger.outputters << Log4r::FileOutputter.new(
            @logger_name,
            {
              :filename =>  "log/#{@logger_name}.log",
              :formatter => formatter
            }
          )
          @logger.outputters << AbfWorker::Outputters::RedisOutputter.new(
            @logger_name, {:formatter => formatter, :worker => self}
          )
        end
        @logger
      end

      def init_tmp_folder
        base_name = name.gsub(/^AbfWorker\:\:/, '').gsub(/Worker(Default)?$/, '').downcase
        @tmp_dir = "#{APP_CONFIG['tmp_path']}/#{base_name}"
        system "mkdir -p -m 0700 #{@tmp_dir}"
      end

      def update_build_status_on_abf(args = {}, force = false)
        Resque.push(
          @observer_queue,
          'class' => @observer_class,
          'args' => [{
            :id     => @build_id,
            :status => @status,
            :extra  => @extra
          }.merge(args)]
        ) if !@skip_feedback || force
      end
      
    end

    def self.logger
      @logger || init_logger('abfworker::base-worker')
    end

  end
end