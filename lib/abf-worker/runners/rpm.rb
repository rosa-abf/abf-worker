require 'abf-worker/exceptions/script_error'
require 'digest/md5'
require 'forwardable'
require 'json'

module AbfWorker
  module Runners
    class Rpm
      extend Forwardable

      RPM_BUILD_SCRIPT_PATH = 'https://abf.rosalinux.ru/avokhmin/rpm-build-script/archive/avokhmin-rpm-build-script-master.tar.gz'

      attr_accessor :script_runner,
                    :can_run,
                    :packages

      def_delegators :@worker, :logger

      def initialize(worker, git_project_address, commit_hash, build_requires, include_repos, bplname, user)
        @user = user
        @worker = worker
        @git_project_address = git_project_address
        @commit_hash = commit_hash
        @build_requires = build_requires
        @include_repos = include_repos
        @bplname = bplname
        @can_run = true
        @packages = []
      end

      def run_script
        @script_runner = Thread.new do
          if @worker.vm.communicator.ready?
            prepare_script
            logger.info '==> Run script...'

            command = []
            command << 'cd rpm-build-script;'
            command << "GIT_PROJECT_ADDRESS=#{@git_project_address}"
            command << "COMMIT_HASH=#{@commit_hash}"
            # command << "ARCH=#{@worker.vm.arch}"
            command << "DISTRIB_TYPE=#{@worker.vm.os}"
            command << "UNAME=#{@user['uname']}"
            command << "EMAIL=#{@user['email']}"
            # command << "BUILD_REQUIRES=#{@build_requires}"
            # command << "INCLUDE_REPOS='#{@include_repos}'"
            command << '/bin/bash build.sh'
            begin
              @worker.vm.execute_command command.join(' ')
              logger.info '==>  Script done with exit_status = 0'
              @worker.status = AbfWorker::BaseWorker::BUILD_COMPLETED
            rescue AbfWorker::Exceptions::ScriptError => e
              logger.info "==>  Script done with exit_status != 0. Error message: #{e.message}"
              @worker.status = AbfWorker::BaseWorker::BUILD_FAILED
            rescue => e
              @worker.print_error e
              @worker.status = AbfWorker::BaseWorker::BUILD_FAILED
            end
            save_results
          end
        end
        @script_runner.join if @can_run
      end

      private

      def save_results
        # Download ISOs and etc.
        logger.info '==> Saving results....'
        project_name = @git_project_address.
          scan(/\/([^\/]+)\.git/).inject.first

        ["tar -zcvf results/#{project_name}-#{@worker.build_id}.tar.gz archives", 'rm -rf archives'].each do |command|
          @worker.vm.execute_command command
        end

        logger.info "==> Downloading results...."
        port = @worker.vm.get_vm.config.ssh.port
        system "scp -r -o 'StrictHostKeyChecking no' -i keys/vagrant -P #{port} vagrant@127.0.0.1:/home/vagrant/results #{@worker.vm.results_folder}"

        container_data = "#{@worker.vm.results_folder}/results/container_data.json"
        if File.exists?(container_data)
          @packages = JSON.parse(IO.read(container_data)).select{ |p| p['name'] }
          File.delete container_data
        end
        logger.info "Done."
      end

      def prepare_script
        logger.info '==> Prepare script...'

        commands = []
        commands << "curl -O -L #{RPM_BUILD_SCRIPT_PATH}"
        file_name = 'avokhmin-rpm-build-script-master.tar.gz'
        commands << "tar -xzf #{file_name}"
        folder_name = file_name.gsub /\.tar\.gz$/, ''

        commands << "mv #{folder_name} rpm-build-script"
        commands << "rm -rf #{file_name}"

        commands.each{ |c| @worker.vm.execute_command(c) }
        init_mock_configs
      end

      def init_mock_configs
        lines = []
        if @worker.vm.os == 'mdv'
          # config_opts['urpmi_media'] = {
          #   'name_1': 'url_1', 'name_2': 'url_2'
          # }
          lines << 'config_opts["urpmi_media"] = {'
          lines << @include_repos.map do |name, url|
            "\"#{name}\": \"#{url}\""
          end.join(', ')
          lines << '}'
        else
          # config_opts['yum.conf'] = """
          #   [main]
          #   cachedir=/var/cache/yum
          #   debuglevel=1
          #   reposdir=/dev/null
          #   logfile=/var/log/yum.log
          #   retries=20
          #   obsoletes=1
          #   gpgcheck=0
          #   assumeyes=1
          #   syslog_ident=mock
          #   syslog_device=

          #   # repos
          #   [base]
          #   name=BaseOS
          #   enabled=1
          #   mirrorlist=http://mirrorlist.centos.org/?release=6&arch=i386&repo=os
          #   failovermethod=priority
          # """
          '
          config_opts["yum.conf"] = """
            [main]
            cachedir=/var/cache/yum
            debuglevel=1
            reposdir=/dev/null
            logfile=/var/log/yum.log
            retries=20
            obsoletes=1
            gpgcheck=0
            assumeyes=1
            syslog_ident=mock
            syslog_device=

            # repos
          '.split("\n").each{ |l| lines << l }
          @include_repos.each do |name, url|
            "
            [#{name}]
            name=#{name}
            enabled=1
            baseurl=#{url}
            failovermethod=priority

            ".split("\n").each{ |l| lines << l }
          end

          lines << '"""'
        end

        config_name = "#{@worker.vm.os}#{@worker.vm.os == 'mdv' && @bplname =~ /lts/ ? '-lts' : ''}-#{@worker.vm.arch}.cfg"
        @worker.vm.execute_command "cp /home/vagrant/rpm-build-script/configs/#{config_name} /home/vagrant/rpm-build-script/configs/default.cfg"
        lines.each{ |line|
          command = "echo '#{line.strip}' >> /home/vagrant/rpm-build-script/configs/default.cfg"
          @worker.vm.execute_command(command)
        }
      end

    end
  end
end