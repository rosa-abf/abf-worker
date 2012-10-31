module AbfWorker
  module Runners
    module Vm
      VAGRANTFILES_FOLDER = File.dirname(__FILE__).to_s << '/../../../vagrantfiles'

      def initialize_vagrant_env
        vagrantfile = "#{VAGRANTFILES_FOLDER}/#{@vm_name}"
        unless File.exist?(vagrantfile)
          begin
            file = File.open(vagrantfile, 'w')
            str = "
              Vagrant::Config.run do |config|
                config.vm.share_folder('v-root', nil, nil)
                config.vm.define '#{@vm_name}' do |vm_config|
                  vm_config.vm.box = '#{@os}.#{@arch}'
                end
              end"
            file.write(str) 
          rescue IOError => e
            logger.error e.message
          ensure
            file.close unless file.nil?
          end
        end
        @vagrant_env = Vagrant::Environment.
          new(:vagrantfile_name => "vagrantfiles/#{@vm_name}")
      end



      def start_vm
        logger.info '==> Up VM...'
        @vagrant_env.cli 'up', @vm_name

        # VM should be exist before using sandbox
        logger.info '==> Enable save mode...'
        Sahara::Session.on(@vm_name, @vagrant_env)
      end

      def rollback_and_halt_vm
        # machine state should be (Running, Paused or Stuck)
        logger.info '==> Rollback activity'
        Sahara::Session.rollback(@vm_name, @vagrant_env)

        logger.info '==> Halt VM...'
        communicator = @vagrant_env.vms[@vm_name.to_sym].communicate
        if communicator.ready?
          communicator.execute 'shutdown -h now', {:sudo => true}
        end
        @vagrant_env.cli 'halt', @vm_name
        logger.info '==> Done.'
      end

      def clean(destroy_all = false)
        files = []
        Dir.new(VAGRANTFILES_FOLDER).entries.each do |f|
          if File.file?(VAGRANTFILES_FOLDER + "/#{f}") &&
              (f =~ /#{@worker_id}/ || destroy_all) && !(f =~ /^\./)
            files << f
          end
        end
        files.each do |f|
          env = Vagrant::Environment.
            new(:vagrantfile_name => "vagrantfiles/#{f}", :ui => false)
          logger.info '==> Halt VM...'
          env.cli 'halt', '-f'

          logger.info '==> Disable save mode...'
          Sahara::Session.off(f, env)

          logger.info '==> Destroy VM...'
          env.cli 'destroy', '--force'

          File.delete(VAGRANTFILES_FOLDER + "/#{f}")
        end
      end

    end
  end
end