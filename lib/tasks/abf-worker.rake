$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib'
require 'abf-worker'
require 'resque/tasks'

namespace :abf_worker do
  desc 'Add test data for Script worker'
  task :test_script do
    script_path = '/home/avokhmin/workspace/warpc/test_script.sh'
    Resque.enqueue(AbfWorker::ScriptWorker, 15, 'rosa', 64, script_path)
  end

  desc 'Add test data for ISO worker'
  task :test_iso do
    build_id = 15
    lst = 'kde'
    externalarch = 'i586'
    productname = 'ROSA.2012.LTS'
    repo = 'http://abf.rosalinux.ru/downloads/rosa2012lts/repository/i586/'
    srcpath = 'https://grendizer@abf.rosalinux.ru/grendizer/test.git'
    branch = 'rosa2012.1'
    # build_id, lst, externalarch, productname, repo, srcpath, branch
    Resque.enqueue(AbfWorker::IsoWorker,
      build_id, lst, externalarch, productname, repo, srcpath, branch)
  end

  desc 'Init VM'
  task :init do
    vm_config = YAML.load_file(File.dirname(__FILE__).to_s + '/../../config/vm.yml')
    vm_config['virtual_machines'].each do |config|
      name, path = config['name'], config['path']
      puts 'Adding and initializing VM...'
      puts "- name: #{name}"
      puts "- path: #{path}"
      puts '-- adding VM...'
      system "vagrant box add #{name} #{path}"
      puts 'Done.'
    end
  end

  desc "Destroy VM's"
  task :destroy_vms do
    AbfWorker::BaseWorker.clean true
  end

end