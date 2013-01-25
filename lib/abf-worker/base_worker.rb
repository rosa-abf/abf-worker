require 'vagrant'
require 'sahara'
require 'sahara/command/vagrant'
require 'net/ssh'
require 'abf-worker/exceptions/script_error'
require 'abf-worker/runners/vm'
require 'abf-worker/outputters/logger'
require 'abf-worker/outputters/redis_outputter'

module AbfWorker
  class BaseWorker
    include Log4r

    BUILD_COMPLETED = 0
    BUILD_FAILED    = 1
    BUILD_PENDING   = 2
    BUILD_STARTED   = 3
    BUILD_CANCELED  = 4
    BUILD_CANCELING = 5

    class << self
      attr_accessor :status,
                    :build_id,
                    :worker_id,
                    :tmp_dir,
                    :server_id,
                    :vm,
                    :live_inspector,
                    :logger_name

      def print_error(e, notify = true)
        begin
          vm_id = @vm.get_vm.id
        rescue => ex
          vm_id = nil
        end
        Airbrake.notify(
          e,
          :parameters => {
            :hostname   => `hostname`.strip,
            :worker_id  => @worker_id,
            :build_id   => @build_id,
            :vm_id      => vm_id
          }
        ) if notify
        
        a = []
        a << '==> ABF-WORKER-ERROR-START'
        a << 'Something went wrong, report has been sent to ABF team, please try again.'
        a << 'If this error will be happen again, please inform us using https://abf.rosalinux.ru/contact'
        a << '----------'
        a << e.message
        a << e.backtrace.join("\n")
        a << '<== ABF-WORKER-ERROR-END'
        logger.error a.join("\n")
      end

      protected

      def initialize_live_inspector(time_living)
        @live_inspector = AbfWorker::Inspectors::LiveInspector.new(self, time_living)
        @live_inspector.run
      end

      def initialize(options)
        @extra = options['extra'] || {}
        @skip_feedback = options['skip_feedback'] || false
        @status = BUILD_STARTED
        @build_id = options['id']
        @worker_id = Process.ppid
        init_tmp_folder_and_server_id
        update_build_status_on_abf
        @vm = Runners::Vm.new(self, options['distrib_type'], options['arch'])
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

      def init_tmp_folder_and_server_id
        @server_id = ENV['SERVER_ID'] || '1'
        @tmp_dir = "#{APP_CONFIG['tmp_path']}/server-#{@server_id}/#{name}"
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

    def self.clean_up
      init_tmp_folder_and_server_id
      @vm = Runners::Vm.new(self, nil, nil)
      @vm.clean true
    end

    def self.logger
      @logger || init_logger('abfworker::base-worker')
    end

  end
end