# -*- encoding : utf-8 -*-
# require "whenever/capistrano"

set :branch, "master"

# TODO: change IP
set :domain, "195.19.76.230"
set :port, 222

role :app, domain
role :web, domain
role :db,  domain, :primary => true