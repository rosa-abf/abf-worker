$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib'
require 'abf-worker'
require 'resque/tasks'

namespace :abf_worker do
  desc 'Add test data for ISO worker'
  task :test_iso do
    build_id = 16
    lst = 'kde'
    externalarch = 'i586'
    productname = 'ROSA.2012.LTS'
    repo = 'http://abf.rosalinux.ru/downloads/rosa2012lts/repository/i586/'
    srcpath = 'https://abf.rosalinux.ru/avokhmin/test.git'
    branch = 'abf-worker'
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