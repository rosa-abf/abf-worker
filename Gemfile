source "http://rubygems.org"

gem 'resque'
gem 'vagrant', :git => 'git://github.com/avokhmin/vagrant.git',
  :branch => 'abf-worker'
gem 'sahara', :git => 'git://github.com/avokhmin/sahara.git',
  :branch => 'update-to-vagrant-1.1.0'
gem 'log4r', '1.1.10'

group :development do
  gem 'veewee', '0.3.1', :git => 'git://github.com/avokhmin/veewee.git',
    :branch => 'rosa-linux'
  # deploy
  gem 'capistrano', :require => false
  gem 'rvm-capistrano', :require => false
  gem 'cape', :require => false
  gem 'capistrano_colors', :require => false
end
