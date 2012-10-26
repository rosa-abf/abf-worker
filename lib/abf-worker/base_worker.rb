require 'abf-worker/runners/vm'
require 'vagrant'
require 'sahara'
require 'sahara/command/vagrant'
require 'net/ssh'
require 'log4r'

module AbfWorker
  class BaseWorker
    include Log4r
    extend Runners::Vm


    def self.init_logger(logger_name = nil)
      @logger = Log4r::Logger.new logger_name, ALL
      @logger.outputters << Log4r::Outputter.stdout
      @logger.outputters << Log4r::FileOutputter.
        new(logger_name, :filename =>  "logs/#{logger_name}.log")
      @logger
    end

    def self.logger
      @logger || init_logger('abfworker::base-worker')
    end

  end
end