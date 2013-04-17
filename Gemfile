source "http://rubygems.org"

gem 'rake'
gem 'resque', :git => 'git://github.com/avokhmin/resque.git', :branch => 'master'
gem 'redis', :git => 'git://github.com/avokhmin/redis-rb.git',
  :branch => '735-reconnect-on-timeout-error'
gem 'vagrant', :git => 'git://github.com/warpc/vagrant.git',
  :branch => 'abf-worker'
gem 'sahara', :git => 'git://github.com/avokhmin/sahara.git',
  :branch => 'update-to-vagrant-1.1.0'
gem 'log4r', '1.1.10'
gem 'api_smith', '1.2.0'

gem 'newrelic_rpm', '~> 3.5.5.38', :platforms => [:mri, :rbx]
group :production do
  gem 'airbrake', '~> 3.1.6'
end

group :development do
  gem 'veewee', '0.3.1', :git => 'git://github.com/avokhmin/veewee.git',
    :branch => 'rosa-linux'
  # deploy
  gem 'capistrano', :require => false
  gem 'rvm-capistrano', :require => false
  gem 'cape', :require => false
  gem 'capistrano_colors', :require => false
end
