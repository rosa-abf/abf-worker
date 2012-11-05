require 'abf-worker/base_worker'
require 'abf-worker/runners/iso'

module AbfWorker
  class IsoWorker < BaseWorker
    extend Runners::Iso

    @queue = :iso_worker

    # Initialize a new ISO worker.
    #
    # @param [Integer] build_id The identifier of current build
    # @param [String] lst Type lst which will be used for building
    # @param [String] externalarch The ISO architecture
    # @param [String] productname The chroot name
    # @param [String] srcpath The path for build scripts
    # @param [String] repo The repository for chroot
    # @param [String] branch The branch of repository
    def self.initialize(build_id, lst, externalarch, productname, repo, srcpath, branch)
      super(build_id, productname, externalarch)
      @lst = lst
      @externalarch = externalarch
      @productname = productname
      @repo = repo
      @srcpath = srcpath
      @branch = branch
    end

    def self.perform(build_id, lst, externalarch, productname, repo, srcpath, branch)
      initialize build_id, lst, externalarch, productname, repo, srcpath, branch
      initialize_vagrant_env
      start_vm
      run_script
      rollback_and_halt_vm
    rescue Resque::TermException
      clean
    rescue Exception => e
      logger.error e.message
      rollback_and_halt_vm
    end

    def self.logger
      @logger || init_logger("abfworker::iso-worker-#{@build_id}")
    end

  end
end