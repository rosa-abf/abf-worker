current_path  = ENV['CURRENT_PATH'] or raise "CURRENT_PATH not set"
group         = ENV['GROUP'] or raise "GROUP not set"

env = {}
%w(RESQUE_TERM_TIMEOUT TERM_CHILD ENV BACKGROUND INTERVAL QUEUE).each do |key|
  env[key] = ENV[key] or raise "#{key} not set"
end

ENV['COUNT'].to_i.times do |num|
  God.watch do |w|
    w.dir      = "#{current_path}"
    w.group    = group
    w.name     = "#{w.group}-#{num}"
    w.interval = 60.seconds
    w.pid_file = "#{current_path}/tmp/pids/#{w.name}.pid"
    w.env      = env.merge('PIDFILE' => w.pid_file)
    w.start    = "bundle exec rake abf_worker:safe_clean_up && #{w.env.map{|k, v| "#{k}=#{v}"}.join(' ')} bundle exec rake resque:work &"

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
        c.interval = 5.seconds
      end

      # failsafe
      on.condition(:tries) do |c|
        c.times = 5
        c.transition = :start
        c.interval = 10.seconds
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
