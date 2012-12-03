require 'resque'
require 'abf-worker/base_worker'
require 'abf-worker/iso_worker'
require 'abf-worker/rpm_worker'
require 'abf-worker/runners/vm'

root = File.dirname(__FILE__) + '/..'
env = ENV['ENV'] || 'development'

resque_config = YAML.load_file(root.to_s + '/config/resque.yml')
Resque.redis = resque_config[env]