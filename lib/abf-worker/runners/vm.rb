require 'forwardable'
require 'digest/md5'
require 'abf-worker/inspectors/vm_inspector'
require 'socket'
require 'fileutils'

module AbfWorker::Runners
  class Vm
    extend Forwardable

    TWO_IN_THE_TWENTIETH = 2**20

    LOG_FOLDER    = File.dirname(__FILE__).to_s << '/../../../log'
    CONFIG_FOLDER = File.dirname(__FILE__).to_s << '/../../../config'

    attr_accessor :vagrant_env,
                  :platform,
                  :arch,
                  :share_folder

    def_delegators :@worker, :logger

    def initialize(worker, options)
      @worker   = worker
      @type     = options['type']
      @platform = options['name']
      @arch     = options['arch']
      # @vm_name = "#{@os}.#{can_use_x86_64_for_x86? ? 'x86_64' : @arch}_#{@worker.worker_id}"
      @vm_name = "#{vm_box}_#{@worker.worker_id}"
      @share_folder = nil
    end

    def initialize_vagrant_env
      vagrantfile = "#{vagrantfiles_folder}/#{@vm_name}"
      first_run = false
      unless File.exist?(vagrantfile)
        begin
          file = File.open(vagrantfile, 'w')
          port = 2000 + (@worker.build_id % 63000)
          arch = can_use_x86_64_for_x86? ? 'x86_64' : @arch
          str = "
            Vagrant::Config.run do |config|
              config.vm.define '#{@vm_name}' do |vm_config|
                #{share_folder_config}
                vm_config.vm.box = '#{vm_box}'
                vm_config.vm.forward_port 22, #{port}
                vm_config.ssh.port = #{port}
                vm_config.vm.customize  ['modifyvm', :id, '--memory', #{APP_CONFIG['vm']["#{arch}"]}]
                vm_config.vm.customize  ['modifyvm', :id, '--cpus', 3]
                vm_config.vm.customize  ['modifyvm', :id, '--hwvirtex', 'on']
                vm_config.vm.customize  ['modifyvm', :id, '--largepages', 'on']
                vm_config.vm.customize  ['modifyvm', :id, '--nestedpaging', 'on']
                vm_config.vm.customize  ['modifyvm', :id, '--nictype1', 'virtio']
                vm_config.vm.customize  ['modifyvm', :id, '--chipset', 'ich9']
              end
            end"
          file.write(str)
          first_run = true
        rescue IOError => e
          @worker.print_error e
        ensure
          file.close unless file.nil?
        end
      end
      if !first_run && @share_folder
        system "sed \"4s|.*|#{share_folder_config}|\" #{vagrantfile} > #{vagrantfile}_tmp"
        system "mv #{vagrantfile}_tmp #{vagrantfile}"
      end

      @vagrant_env = Vagrant::Environment.new(
        :cwd => vagrantfiles_folder,
        :vagrantfile_name => @vm_name
      )
      `sudo chown -R rosa:rosa #{@share_folder}/../` if @share_folder

      if first_run
        # First startup of VMs one by one
        synchro_file = "#{@worker.tmp_dir}/../vm.synchro"
        begin
          while !system("lockfile -r 0 #{synchro_file}") do
            sleep rand(10)
          end
          logger.log 'Up VM at first time...'
          @vagrant_env.cli 'up', @vm_name
          sleep 1
        rescue => e
          @worker.print_error e
        ensure
          system "rm -f #{synchro_file}"
        end
        sleep 10
        logger.log 'Configure VM...'
        # Fix for DNS problems
        %(/bin/bash -c 'echo "185.4.234.68 file-store.rosalinux.ru" >> /etc/hosts'
          /bin/bash -c 'echo "195.19.76.241 abf.rosalinux.ru" >> /etc/hosts'
        ).split("\n").each{ |c| execute_command(c, {:sudo => true}) }
        download_scripts
        [
          'cd scripts/startup-vm/; /bin/bash startup.sh',
          'rm -rf scripts'
        ].each{ |c| execute_command(c) }

        # VM should be exist before using sandbox
        logger.log 'Enable save mode...'
        Sahara::Session.on @vm_name, @vagrant_env
      else
        if @share_folder
          Sahara::Session.off @vm_name, @vagrant_env
          system "VBoxManage sharedfolder remove #{get_vm.id} --name v-root"
          system "VBoxManage sharedfolder add #{get_vm.id} --name v-root --hostpath #{@share_folder}"
          sleep 10
          run_with_vm_inspector {
            @vagrant_env.cli 'up', @vm_name
          }
          sleep 10
          Sahara::Session.on @vm_name, @vagrant_env
        end
      end # first_run
    end

    def upload_file(from, to)
      system "scp -o 'StrictHostKeyChecking no' -i keys/vagrant -P #{ssh_port} #{from} vagrant@127.0.0.1:#{to}"
    end

    def download_folder(from, to)
      system "scp -r -o 'StrictHostKeyChecking no' -i keys/vagrant -P #{ssh_port} vagrant@127.0.0.1:#{from} #{to}"
    end

    def get_vm
      @vagrant_env.vms[@vm_name.to_sym]
    end

    def start_vm
      logger.log "Host name '#{Socket.gethostname}'"
      logger.log "Up VM '#{get_vm.id}'..."
      run_with_vm_inspector {
        @vagrant_env.cli 'up', @vm_name
      }
      rollback_vm
    end

    def rollback_and_halt_vm
      rollback_vm
      logger.log 'Halt VM...'
      run_with_vm_inspector {
        @vagrant_env.cli 'halt', @vm_name, '-f'
      }
      sleep 10
      logger.log 'Done.'
      yield if block_given?
    end

    def clean
      files = []
      Dir.new(vagrantfiles_folder).entries.each do |f|
        if File.file?(vagrantfiles_folder + "/#{f}") && f =~ /#{@worker.worker_id}/
          files << f
        end
      end

      files.each do |f|
        begin
          env = Vagrant::Environment.new(
            :vagrantfile_name => f,
            :cwd => vagrantfiles_folder,
            :ui => false
          )

          id = env.vms[f.to_sym].id

          ps = %x[ ps aux | grep VBox | grep #{id} | grep -v grep | awk '{ print $2 }' ].
            split("\n").join(' ')
          system "sudo kill -9 #{ps}" unless ps.empty?

          logger.log 'Destroy VM...'
          env.cli 'destroy', '--force'

        rescue => e
        ensure
          File.delete(vagrantfiles_folder + "/#{f}")
        end
      end
      yield if block_given?
    end

    def execute_command(command, opts = nil)
      opts = {
        :sudo => false,
        :error_class => AbfWorker::Exceptions::ScriptError
      }.merge(opts || {})
      logger.log "Execute command with sudo = #{opts[:sudo]}: #{command}", '-->'
      if communicator.ready?
        communicator.execute command, opts do |channel, data|
          logger.log data, '', false
        end
      end
    rescue AbfWorker::Exceptions::ScriptError => e
      raise e # Throws ScriptError with exit_status
    rescue => e
      raise AbfWorker::Exceptions::ScriptError, command
    end

    def upload_results_to_file_store
      uploaded = []
      if File.exists?(results_folder) && File.directory?(results_folder)
        # Dir.new(results_folder).entries.each do |f|
        Dir[results_folder + '/**/'].each do |folder|
          Dir.new(folder).entries.each do |f|
            uploaded << upload_file_to_file_store(folder, f)
          end
        end
        system "rm -rf #{results_folder}"
      end
      uploaded << upload_file_to_file_store(LOG_FOLDER, "#{@worker.logger_name}.log")
      uploaded.compact
    end

    def communicator
      @communicator ||= get_vm.communicate
    end

    def results_folder
      return @results_folder if @results_folder
      @results_folder = "#{@worker.tmp_dir}/results/build-#{@worker.build_id}"
      system "rm -rf #{@results_folder} && mkdir -p #{@results_folder}"
      @results_folder
    end

    def rollback_vm
      # machine state should be (Running, Paused or Stuck)
      logger.log 'Rollback activity'
      sleep 10
      run_with_vm_inspector {
        Sahara::Session.rollback(@vm_name, @vagrant_env)
      }
      sleep 5
    end

    def download_scripts
      logger.log 'Prepare script...'

      script  = APP_CONFIG['scripts']["#{@type}"]
      treeish = script['treeish']
      [
        "rm -rf #{treeish}.tar.gz #{treeish} scripts",
        "curl -O -L #{script['path']}#{treeish}.tar.gz",
        "tar -xzf #{treeish}.tar.gz",
        "mv #{treeish} scripts",
        "rm -rf #{treeish}.tar.gz"
      ].each{ |c| execute_command(c) }
    end

    private

    def share_folder_config
      if @share_folder
        logger.log "Share folder: #{@share_folder}"
        "vm_config.vm.share_folder('v-root', '/home/vagrant/share_folder', '#{@share_folder}')"
      else
        "vm_config.vm.share_folder('v-root', nil, nil)"
      end
    end

    def can_use_x86_64_for_x86?
      # Override @arch, and up x86_64 for all workers
      true
    end

    def vm_box
      return @vm_box if @vm_box
      vm_yml = YAML.load_file(CONFIG_FOLDER + '/vm.yml')

      configs = vm_yml[@type]
      if platform = configs.fetch('platforms', {})[@platform]
        @vm_box = platform[@arch]
        @vm_box ||= platform['noarch']
      else
        @vm_box = configs['default'][@arch]
        @vm_box ||= configs['default']['noarch']
      end
      return @vm_box
    end

    def url_to_build
      return @url_to_build if @url_to_build
      path = @worker.runner.is_a?(AbfWorker::Runners::Iso) ? 'product_build_lists' : 'build_lists'
      @url_to_build = "#{APP_CONFIG['abf_url']}/#{path}/#{@worker.build_id}"
    end

    def upload_file_to_file_store(path, file_name)
      path_to_file = path + '/' + file_name
      return unless File.file?(path_to_file)
      if file_name =~ /.log$/
        tmp_file = "#{path_to_file}.tmp"
        File.open(tmp_file, 'w') do |f|
          f.puts "==> See: '#{url_to_build}'"
          f.puts ''
          File.foreach(path_to_file){ |li| f.puts li }
        end
        File.rename tmp_file, path_to_file
      end

      # Compress the log when file size more than 10MB
      file_size = (File.size(path_to_file).to_f / TWO_IN_THE_TWENTIETH).round(2)
      if path == LOG_FOLDER && file_size >= 10
        system "tar -zcvf #{path_to_file}.tar.gz #{path_to_file}"
        File.delete path_to_file
        path_to_file << '.tar.gz'
        file_name << '.tar.gz'
      end

      logger.log "Uploading file '#{file_name}'...."
      sha1 = Digest::SHA1.file(path_to_file).hexdigest

      # curl --user myuser@gmail.com:mypass -POST -F "file_store[file]=@files/archive.zip" http://file-store.rosalinux.ru/api/v1/file_stores.json
      if %x[ curl #{APP_CONFIG['file_store']['url']}.json?hash=#{sha1} ] == '[]'
        command = 'curl --user '
        command << file_store_token
        command << ': -POST -F "file_store[file]=@'
        command << path_to_file
        command << '" '
        command << APP_CONFIG['file_store']['create_url']
        logger.log %x[ #{command} ]
      end

      File.delete path_to_file
      logger.log 'Done.'
      {:sha1 => sha1, :file_name => file_name, :size => file_size}
    end

    def vagrantfiles_folder
      @vagrantfiles_folder ||= FileUtils.mkdir_p(@worker.tmp_dir + '/vagrantfiles').first
    end

    def file_store_token
      @file_store_token ||= APP_CONFIG['file_store']['token']
    end

    def run_with_vm_inspector
      vm_inspector = AbfWorker::Inspectors::VMInspector.new @worker
      vm_inspector.run
      yield if block_given?
      vm_inspector.stop
    end

    def ssh_port
      @ssh_port ||= get_vm.config.ssh.port 
    end

  end
end