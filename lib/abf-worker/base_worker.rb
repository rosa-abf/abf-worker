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
    extend Runners::Vm

    def self.initialize(build_id, os, arch)
      @status = AbfWorker::Runners::Iso::BUILD_STARTED
      @build_id = build_id
      @os = os
      @arch = arch
      @worker_id = Process.ppid
      @vm_name = "#{@os}.#{@arch}_#{@worker_id}"
      self.init_tmp_folder_and_server_id
      self.update_build_status_on_abf
    end

    def self.init_logger(logger_name = nil)
      @logger = Log4r::Logger.new logger_name, ALL
      @logger.outputters << Log4r::Outputter.stdout
      @logger.outputters << Log4r::FileOutputter.
        new(logger_name, :filename =>  "log/#{logger_name}.log")
      @logger.outputters << AbfWorker::Outputters::RedisOutputter.new(logger_name)
      @logger
    end

    def self.logger
      @logger || init_logger('abfworker::base-worker')
    end

    def self.init_tmp_folder_and_server_id
      @server_id = ENV['SERVER_ID'] || '1'
      @tmp_dir = ''
      base = ENV['ENV'] == 'production' ? '/mnt/store/tmp/abf-worker-tmp' : "#{Dir.pwd}/abf-worker-tmp"
      [base, "server-#{@server_id}", name].each do |d|
        @tmp_dir << '/'
        @tmp_dir << d
        Dir.mkdir(@tmp_dir) unless File.exists?(@tmp_dir)
      end
    end

    def self.update_build_status_on_abf(args = {})
      Resque.push(
        @observer_queue,
        'class' => @observer_class,
        'args' => [{
          :id => @build_id,
          :status => @status
        }.merge(args)]
      )
    end

  end
end