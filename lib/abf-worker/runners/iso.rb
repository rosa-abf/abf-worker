module AbfWorker
  module Runners
    module Iso
      BUILD_ISO_SCRIPT = File.dirname(__FILE__).to_s << '/../../../scripts/build_iso.sh'
      ISO_FOLDER = File.dirname(__FILE__).to_s << '/../../../iso'

      def run_script
        communicator = @vagrant_env.vms[@vm_name.to_sym].communicate
        if communicator.ready?
          prepare_script communicator
          logger.info '==> Run script...'

          commands = []
          command = {
            'lst' => @lst,
            'externalarch' => @externalarch,
            'PRODUCTNAME' => @productname,
            'REPO' => @repo,
            'SRCPATH' => @srcpath,
            'branch' => @branch
          }.map{ |k, v| "#{k}=#{v}" }.join(' ')
          command << ' /home/vagrant/script.sh'
          commands << command

          commands.each do |c|
            communicator.execute command, {:sudo => true} do |channel, data|
              logger.info data 
            end
          end
          # Download ISO
          #communicator.download('', ISO_FOLDER)
        end
      end

      def prepare_script(communicator)
        logger.info '==> Prepare script...'
        # Upload script from server into the VM
        communicator.upload(BUILD_ISO_SCRIPT, '/home/vagrant/script.sh')
      end

    end
  end
end