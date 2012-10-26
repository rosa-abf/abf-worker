require 'vagrant'
require 'sahara'
require 'sahara/command/vagrant'
require 'net/ssh'

module AbfWorker
  class Worker

    VAGRANTFILES_FOLDER = File.dirname(__FILE__).to_s << '/../../vagrantfiles'
    @queue = :worker

    def self.initialize(build_id, os, arch, script_path)
      @build_id = build_id
      @os = os
      @arch = arch
      @script_path = script_path
      @worker_id = ''#Process.getpgid(Process.ppid)
      @vm_name = "#{@os}_#{@arch}_#{@worker_id}"
    end

    def self.initialize_vagrant_env
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

    def self.perform(os, arch, script_path)
      initialize os, arch, script_path
      initialize_vagrant_env
      start_vm
      run_script
      rollback_and_halt_vm
    rescue Resque::TermException
      clean
    rescue Exception => e
      puts e.message
      rollback_and_halt_vm
    ensure
#      Log4r::Logger.each do |k, v|
#        if k =~ /vagrant/
#          v.outputters = []
#        end
#      end
    end

    def self.run_script
      puts 'Run scripts...'
      # TODO: run script
      commands = ['ls -l','ls -l /vagrant', 'touch /vagrant/from_vb.txt']

      communicator = @vagrant_env.vms[@vm_name.to_sym].communicate
      if communicator.ready?
        commands.each{ |c| communicator.execute c }
      end
    end

    def self.start_vm
      puts 'Start to run vagrant-up...'
      @vagrant_env.cli 'up', @vm_name
      puts 'Finished running vagrant-up'

      # VM should be exist before using sandbox
      puts 'Enter sandbox mode'
      Sahara::Session.on(@vm_name, @vagrant_env)
    end

    def self.rollback_and_halt_vm
      # machine state should be (Running, Paused or Stuck)
      puts 'Rollback actions'
      Sahara::Session.rollback(@vm_name, @vagrant_env)

      puts 'Start to run vagrant-halt...'
      @vagrant_env.cli 'halt', @vm_name
      puts 'Finished running vagrant-halt'
    end

    def self.clean(destroy_all = false)
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


    def self.ssh_command(session, cmd)
      session.open_channel do |channel|
        channel.exec(cmd) do |ch, success|                                                  
          ch.on_data do |ch2, data|
            puts "STDOUT: #{data}"                                                  
          end
          ch.on_extended_data do |ch2, type, data|                                          
            puts "STDERR: #{data}"                                                  
          end
          ch.on_request "exit-status" do |ch2, data|                                        
            return data.read_long                                                           
          end                                                                               
        end                                                                                 
      end
      session.loop                                                                          
    end 

  end
end