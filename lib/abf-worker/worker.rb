require 'vagrant'
module AbfWorker
  class Worker
    VAGRANTFILES_FOLDER = File.dirname(__FILE__).to_s << '/../../vagrantfiles'
    @queue = :worker

    def self.initialize(os, arch, script_path)
      @os = os
      @arch = arch
      @script_path = script_path
      @worker_id = Process.getpgid(Process.ppid)
      @vm_name = "#{@os}_#{@arch}_#{@worker_id}"
    end

    def self.initialize_vagrant_env
      vagrantfile = "#{VAGRANTFILES_FOLDER}/#{@vm_name}"
      unless File.exist?(vagrantfile)
        begin
          file = File.open(vagrantfile, "w")
          str = "
            Vagrant::Config.run do |config|
              config.vm.share_folder('v-root', '/vagrant', '.', :extra => 'dmode=770,fmode=770')
              config.vm.define :#{@vm_name} do |vm_config|
                vm_config.vm.box = '#{@os}_#{@arch}'
              end
            end"
          file.write(str) 
        rescue IOError => e
          #some error occur, dir not writable etc.
        ensure
          file.close unless file.nil?
        end
      end
      @vagrant_env = Vagrant::Environment.
        new(:vagrantfile_name => "#{VAGRANTFILES_FOLDER}/#{@vm_name}")
    end

    def self.perform(os, arch, script_path)
      self.initialize os, arch, script_path
      self.initialize_vagrant_env

      puts 'Start to run vagrant-up...'
      @vagrant_env.cli 'up', @vm_name
      puts 'Finished running vagrant-up'

      # VM should be exist before using sandbox
      puts 'Enter sandbox mode'
      Sahara::Session.on(@vm_name, @vagrant_env)

      # TODO: run script

      # machine state should be (Running, Paused or Stuck)
      puts 'Rollback actions'
      Sahara::Session.rollback(@vm_name, @vagrant_env)

      puts 'Start to run vagrant-halt...'
      @vagrant_env.cli 'halt', @vm_name
      puts 'Finished running vagrant-halt'
    rescue Resque::TermException
      clean
    end

    def self.clean
      files = []
      Dir.new(VAGRANTFILES_FOLDER).entries.each do |f|
        if File.file?(path + "/#{f}") && f =~ /#{@worker_id}/
          files << f
        end
      end
      files.each do |f|
        env = Vagrant::Environment.
          new(:vagrantfile_name => "#{VAGRANTFILES_FOLDER}/#{f}")
        puts 'Halt VM...'
        env.cli 'halt', '-f'

        puts 'Exit sandbox mode'
        Sahara::Session.off(f, env)

        puts 'Destroy VM...'
        env.cli 'destroy', '-f'


        File.delete(path + "/" + f)
      end
    end

  end
end