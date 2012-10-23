$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib'
require 'abf-worker'
require 'resque/tasks'

namespace :abf_worker do
  desc "Run worker"
  task :run do
    box_path = '/home/avokhmin/workspace/warpc/CentOS-6.3-x86_64-minimal.box'
    script_path = '/home/avokhmin/workspace/warpc/test_script.sh'
    Resque.enqueue(AbfWorker::Worker, box_path, script_path)
  end
end