require 'resque'


root = File.dirname(__FILE__) + '/..'
env = ENV['ENV'] || 'development'

resque_config = YAML.load_file("#{root}/config/resque.yml")
Resque.redis = resque_config[env]

APP_CONFIG = YAML.load_file("#{root}/config/application.yml")[env]

require 'abf-worker/base_worker'
require 'abf-worker/iso_worker'
require 'abf-worker/rpm_worker'
require 'abf-worker/publish_worker'