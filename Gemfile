source "http://rubygems.org"

gem 'rake'
gem 'resque', '1.23.0'
gem 'redis', '3.0.2'
gem 'vagrant', :git => 'git://github.com/avokhmin/vagrant.git',
  :branch => 'abf-worker'
gem 'sahara', :git => 'git://github.com/avokhmin/sahara.git',
  :branch => 'update-to-vagrant-1.1.0'
gem 'log4r', '1.1.10'
gem 'yajl-ruby', '1.1.0'

group :development do
  gem 'veewee', '0.3.1', :git => 'git://github.com/avokhmin/veewee.git',
    :branch => 'rosa-linux'
  # deploy
  gem 'capistrano', :require => false
  gem 'rvm-capistrano', :require => false
  gem 'cape', :require => false
  gem 'capistrano_colors', :require => false
end
