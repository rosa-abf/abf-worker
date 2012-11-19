module AbfWorker
  module Runners
    module Vm

      def vagrantfiles_folder
        return @vagrantfiles_folder if @vagrantfiles_folder
        @vagrantfiles_folder = @tmp_dir + '/vagrantfiles'
        Dir.mkdir(@vagrantfiles_folder) unless File.exists?(@vagrantfiles_folder)
        @vagrantfiles_folder 
      end

      def initialize_vagrant_env
        vagrantfile = "#{vagrantfiles_folder}/#{@vm_name}"
        first_run = false
        unless File.exist?(vagrantfile)
          begin
            file = File.open(vagrantfile, 'w')
            port = 2000 + (@build_id % 63000)
            str = "
              Vagrant::Config.run do |config|
                config.vm.share_folder('v-root', nil, nil)
                config.vm.define '#{@vm_name}' do |vm_config|
                  vm_config.vm.box = '#{@os}.#{@arch}'
                  vm_config.vm.forward_port 22, #{port}
                  vm_config.ssh.port = #{port}
                end
              end"
            file.write(str)
            first_run = true
          rescue IOError => e
            logger.error e.message
          ensure
            file.close unless file.nil?
          end
        end
        @vagrant_env = Vagrant::Environment.new(
          :cwd => vagrantfiles_folder,
          :vagrantfile_name => @vm_name
        )
        # Hook for fix:
        # ERROR warden: Error occurred: uninitialized constant VagrantPlugins::ProviderVirtualBox::Action::Customize::Errors
        # on vm_config.vm.customizations << ['modifyvm', :id, '--memory',  '#{memory}']
        # and config.vm.customize ['modifyvm', '#{@vm_name}', '--memory', '#{memory}']
        if first_run

          File.open("#{@tmp_dir}/vm.synchro", File::RDWR|File::CREAT, 0644) do |f|
            f.flock(File::LOCK_EX)
            logger.info '==> Up VM at first time...'
            @vagrant_env.cli 'up', @vm_name
            sleep 1
          end
          sleep 30

          logger.info '==> Configure VM...'
          # Halt, because: The machine 'abf-worker_...' is already locked for a session (or being unlocked)
          @vagrant_env.cli 'halt', @vm_name
          sleep 20
          vm_id = @vagrant_env.vms.first[1].id
          memory = @arch == 'i586' ? 4096 : 8192
          # memory = @arch == 'i586' ? 512 : 1024
          # see: http://code.google.com/p/phpvirtualbox/wiki/AdvancedSettings
          ["--memory #{memory}", '--cpus 2', '--hwvirtex on', '--nestedpaging on', '--largepages on'].each do |c|
            system "VBoxManage modifyvm #{vm_id} #{c}"
          end

          sleep 10
          start_vm true
          sleep 30
          # VM should be exist before using sandbox
          logger.info '==> Enable save mode...'
          Sahara::Session.on(@vm_name, @vagrant_env)
        end
      end

      def start_vm(first_run = false)
        logger.info '==> Up VM...'
        @vagrant_env.cli 'up', @vm_name
        rollback_vm unless first_run
      end

      def rollback_vm
        # machine state should be (Running, Paused or Stuck)
        logger.info '==> Rollback activity'
        Sahara::Session.rollback(@vm_name, @vagrant_env)
      end

      def rollback_and_halt_vm
        rollback_vm
        logger.info '==> Halt VM...'
        @vagrant_env.cli 'halt', @vm_name
        logger.info '==> Done.'
        yield if block_given?
      end

      def clean(destroy_all = false)
        files = []
        Dir.new(vagrantfiles_folder).entries.each do |f|
          if File.file?(vagrantfiles_folder + "/#{f}") &&
              (f =~ /#{@worker_id}/ || destroy_all) && !(f =~ /^\./)
            files << f
          end
        end
        files.each do |f|
          env = Vagrant::Environment.new(
            :vagrantfile_name => f,
            :cwd => vagrantfiles_folder,
            :ui => false
          )
          logger.info '==> Halt VM...'
          env.cli 'halt', '-f'

          logger.info '==> Disable save mode...'
          Sahara::Session.off(f, env)

          logger.info '==> Destroy VM...'
          env.cli 'destroy', '--force'

          File.delete(vagrantfiles_folder + "/#{f}")
        end
        yield if block_given?
      end

    end
  end
end