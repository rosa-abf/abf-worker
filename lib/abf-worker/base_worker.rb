require 'vagrant'
require 'sahara'
require 'sahara/command/vagrant'
require 'net/ssh'
require 'log4r'
require 'abf-worker/runners/vm'
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

      def print_error(e)
        a = []
        a << '==> ABF-WORKER-ERROR-START'
        a << 'Please inform us using https://abf.rosalinux.ru/contact'
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
        @save_results = options['save_results'].nil? ? true : options['save_results']
        @status = BUILD_STARTED
        @build_id = options['id']
        @worker_id = Process.ppid
        init_tmp_folder_and_server_id
        update_build_status_on_abf
        @vm = Runners::Vm.new(self, options['distrib_type'], options['arch'])
      end

      def init_logger(logger_name = nil, redis_outputter = true)
        @logger_name = logger_name
        @logger = Log4r::Logger.new @logger_name, Log4r::ALL
        @logger.outputters << Log4r::Outputter.stdout

        # see: https://github.com/colbygk/log4r/blob/master/lib/log4r/formatter/patternformatter.rb#L22
        formatter = Log4r::PatternFormatter.new(:pattern => "%m")
        @logger.outputters << Log4r::FileOutputter.new(
          @logger_name,
          {
            :filename =>  "log/#{@logger_name}.log",
            :formatter => formatter
          }
        ) if @save_results
        @logger.outputters << AbfWorker::Outputters::RedisOutputter.new(
          @logger_name, {:formatter => formatter, :worker => self}
        ) if redis_outputter
        @logger
      end

      def init_tmp_folder_and_server_id
        @server_id = ENV['SERVER_ID'] || '1'
        @tmp_dir = ''
        base = ENV['ENV'] == 'production' ? '/mnt/store/tmp/abf-worker-tmp' : "#{Dir.pwd}/abf-worker-tmp"
        [base, "server-#{@server_id}", name].each do |d|
          @tmp_dir << '/'
          @tmp_dir << d
          Dir.mkdir(@tmp_dir) unless File.exists?(@tmp_dir)
        end
      end

      def update_build_status_on_abf(args = {})
        Resque.push(
          @observer_queue,
          'class' => @observer_class,
          'args' => [{
            :id => @build_id,
            :status => @status
          }.merge(args)]
        ) if @save_results
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