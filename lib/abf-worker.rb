require 'resque'
require 'abf-worker/worker'

root = File.dirname(__FILE__) + '/..'
env = ENV['ENV'] || 'development'

resque_config = YAML.load_file(root.to_s + '/config/resque.yml')
Resque.redis = resque_config[env]