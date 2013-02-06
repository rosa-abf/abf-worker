require 'forwardable'
require 'json'

module AbfWorker
  module Runners
    class Rpm
      extend Forwardable

      attr_accessor :script_runner,
                    :can_run,
                    :packages

      def_delegators :@worker, :logger

      def initialize(worker, options)
        @worker               = worker
        @git_project_address  = options['git_project_address']
        @commit_hash          = options['commit_hash']
        @build_requires       = options['build_requires']
        @include_repos        = options['include_repos']
        @bplname              = options['bplname']
        @user                 = options['user']
        @can_run              = true
        @packages             = []
      end

      def run_script
        @script_runner = Thread.new do
          if @worker.vm.communicator.ready?
            prepare_script
            logger.log 'Run script...'

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
              logger.log 'Script done with exit_status = 0'
              @worker.status = AbfWorker::BaseWorker::BUILD_COMPLETED
            rescue AbfWorker::Exceptions::ScriptError => e
              logger.log "Script done with exit_status != 0. Error message: #{e.message}"
              if e.messages[:exit_status] == AbfWorker::BaseWorker::TESTS_FAILED # 5
                @worker.status = AbfWorker::BaseWorker::TESTS_FAILED
              else
                @worker.status = AbfWorker::BaseWorker::BUILD_FAILED
              end
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
        logger.log 'Saving results....'
        project_name = @git_project_address.
          scan(/\/([^\/]+)\.git/).inject.first

        logger.log "Downloading results...."
        port = @worker.vm.get_vm.config.ssh.port
        system "scp -r -o 'StrictHostKeyChecking no' -i keys/vagrant -P #{port} vagrant@127.0.0.1:/home/vagrant/results #{@worker.vm.results_folder}"

        container_data = "#{@worker.vm.results_folder}/results/container_data.json"
        if File.exists?(container_data)
          @packages = JSON.parse(IO.read(container_data)).select{ |p| p['name'] }
          File.delete container_data
        end
        logger.log "Done."
      end

      def prepare_script
        logger.log 'Prepare script...'

        commands = []
        treeish = APP_CONFIG['scripts']['rpm_build']['treeish']
        commands << "rm -rf #{treeish}.tar.gz #{treeish} rpm-build-script"
        commands << "curl -O -L #{APP_CONFIG['scripts']['rpm_build']['path']}#{treeish}.tar.gz"
        
        file_name = "#{treeish}.tar.gz"
        commands << "tar -xzf #{file_name}"
        commands << "mv #{treeish} rpm-build-script"
        commands << "rm -rf #{file_name}"

        commands.each{ |c| @worker.vm.execute_command(c) }
        init_mock_configs
      end

      def init_mock_configs
        lines = []
        repos_map = {}
        @include_repos.each{ |name, url|
          # Checks that repositoy exist
          if %x[ curl --write-out %{http_code} --silent --output /dev/null #{url} ] == '404'
            logger.log "Repository does not exist: #{url.gsub(/\:\/\/.*\:\@/, '://[FILTERED]@')}"
          else
            repos_map["#{name}"] = url
          end
        }
        if @worker.vm.os == 'mdv'
          # config_opts['urpmi_media'] = {
          #   'name_1': 'url_1', 'name_2': 'url_2'
          # }
          lines << 'config_opts["urpmi_media"] = {'
          lines << repos_map.map do |name, url|
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
          repos_map.each do |name, url|
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