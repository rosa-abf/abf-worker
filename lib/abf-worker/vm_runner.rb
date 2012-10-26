module AbfWorker
  module VmRunner
    VAGRANTFILES_FOLDER = File.dirname(__FILE__).to_s << '/../../vagrantfiles'

    def initialize_vagrant_env
      vagrantfile = "#{VAGRANTFILES_FOLDER}/#{@vm_name}"
      unless File.exist?(vagrantfile)
        begin
          file = File.open(vagrantfile, 'w')
          str = "
            Vagrant::Config.run do |config|
              config.vm.share_folder('v-root', nil, nil)
              config.vm.define :#{@vm_name} do |vm_config|
                vm_config.vm.box = '#{@os}_#{@arch}'
              end
            end"
          file.write(str) 
        rescue IOError => e
          puts e.message
        ensure
          file.close unless file.nil?
        end
      end
      @vagrant_env = Vagrant::Environment.
        new(:vagrantfile_name => "vagrantfiles/#{@vm_name}")
#      logger_name = "#{@vm_name}-#{Process.ppid}"
#      Log4r::Logger.each do |k, v|
#        if k =~ /vagrant/
#          v.outputters << Log4r::FileOutputter.
#            new(logger_name, :filename =>  "logs/#{logger_name}.log")
#        end
#      end
    end



    def start_vm
      puts 'Start to run vagrant-up...'
      @vagrant_env.cli 'up', @vm_name
      puts 'Finished running vagrant-up'

      # VM should be exist before using sandbox
      puts 'Enter sandbox mode'
      Sahara::Session.on(@vm_name, @vagrant_env)
    end

    def rollback_and_halt_vm
      # machine state should be (Running, Paused or Stuck)
      puts 'Rollback actions'
      Sahara::Session.rollback(@vm_name, @vagrant_env)

      puts 'Start to run vagrant-halt...'
      @vagrant_env.cli 'halt', @vm_name
      puts 'Finished running vagrant-halt'
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
        puts 'Halt VM...'
        env.cli 'halt', '-f'

        puts 'Exit sandbox mode'
        Sahara::Session.off(f, env)

        puts 'Destroy VM...'
        env.cli 'destroy', '--force'

        File.delete(VAGRANTFILES_FOLDER + "/#{f}")
      end
    end

  end
end