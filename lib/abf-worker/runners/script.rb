module AbfWorker
  module Runners
    module Script

      def run_script
        communicator = @vagrant_env.vms[@vm_name.to_sym].communicate
        if communicator.ready?
          execute_command communicator, 'ls -la'
          prepare_script communicator
          logger.info '==> Run script...'
          execute_command communicator, 'script/script.sh'
        end
      end

      def prepare_script(communicator)
        logger.info '==> Prepare script...'
        # Create folder for script
        communicator.execute 'mkdir /home/vagrant/script'
        # Upload script from server into the VM
        communicator.upload(@script_path, '/home/vagrant/script/script.sh')
      end

      def execute_command(communicator, command)
        communicator.execute command do |channel, data|
          if channel == :stdout
            logger.info "==== STDOUT:"
          else
            logger.info "==== STDERR:"
          end
          logger.info data 
        end
      end

    end
  end
end