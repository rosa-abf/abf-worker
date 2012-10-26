module AbfWorker
  module Runners
    module Iso
      BUILD_ISO_SCRIPT = File.dirname(__FILE__).to_s << '/../../../scripts/build_iso.sh'

      def run_script
        communicator = @vagrant_env.vms[@vm_name.to_sym].communicate
        if communicator.ready?
          prepare_script communicator
          logger.info '==> Run script...'
          command = {
            'lst' => @lst,
            'externalarch' => @externalarch,
            'PRODUCTNAME' => @productname,
            'REPO' => @repo,
            'SRCPATH' => @srcpath,
            'branch' => @branch
          }.map{ |k, v| "#{k}=#{v}" }.join(' ')
          command << ' /home/vagrant/script/script.sh'

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

      def prepare_script(communicator)
        logger.info '==> Prepare script...'
        # Create folder for script
        communicator.execute 'mkdir /home/vagrant/script'
        # Upload script from server into the VM
        communicator.upload(BUILD_ISO_SCRIPT, '/home/vagrant/script/script.sh')
      end

    end
  end
end