abf_root  = ENV['ABF_ROOT'] or raise "ABF_ROOT not set"
rvm_ruby_string = ENV['RVM_RUBY_STRING'] or raise "RVM_RUBY_STRING not set"

env = {}
%w(RESQUE_TERM_TIMEOUT TERM_CHILD ENV BACKGROUND INTERVAL QUEUE).each do |key|
  env[key] = ENV[key] or raise "#{key} not set"
end


ENV['COUNT'].to_i.times do |num|
  God.watch do |w|
    w.dir      = "#{abf_root}"
    w.name     = "resque-#{num}"
    w.group    = 'resque'
    w.interval = 60.seconds
    w.pid_file = "#{abf_root}/tmp/pids/#{w.name}.pid"
    w.env      = env.merge('PIDFILE' => w.pid_file)
    # w.start    = "bundle exec rake resque:work &"
    w.start    = "rvm #{rvm_ruby_string} exec bundle exec rake abf_worker:safe_clean_up && #{w.env.map{|k, v| "#{k}=#{v}"}.join(' ')} rvm #{rvm_ruby_string} exec bundle exec rake resque:work &"

    # determine the state on startup
    w.transition(:init, { true => :up, false => :start }) do |on|
      on.condition(:process_running) do |c|
        c.running = true
      end
    end

    # determine when process has finished starting
    w.transition([:start, :restart], :up) do |on|
      on.condition(:process_running) do |c|
        c.running = true
        c.interval = 60.seconds
      end

      # failsafe
      on.condition(:tries) do |c|
        c.times = 1_000_000
        c.transition = :start
        c.interval = 60.seconds
      end
    end

    # start if process is not running
    w.transition(:up, :start) do |on|
      on.condition(:process_running) do |c|
        c.running = false
      end
    end
  end
end
