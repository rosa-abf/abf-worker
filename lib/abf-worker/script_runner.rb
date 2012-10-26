module AbfWorker
  module ScriptRunner

    def run_script
      communicator = @vagrant_env.vms[@vm_name.to_sym].communicate
      if communicator.ready?
        prepare_script communicator
        @logger.info '==> Run script...'
        communicator.execute '/home/vagrant/script/script.sh' do |channel, data|
          if channel == :stdout
            @logger.info "==== STDOUT:"
          else
            @logger.info "==== STDERR:"
          end
          @logger.info data 
        end
      end
    end

    def prepare_script(communicator)
      @logger.info '==> Prepare script...'
      # Create folder for script
      communicator.execute 'mkdir /home/vagrant/script'
      # Upload script from server into the VM
      communicator.upload(@script_path, '/home/vagrant/script/script.sh')
    end

  end
end