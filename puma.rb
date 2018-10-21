root = "#{Dir.getwd}"

bind "unix://#{root}/logs/socket"
pidfile "#{root}/logs/pid"
state_path "#{root}/logs/state"
rackup "#{root}/config.ru"

workers Integer(ENV['WEB_CONCURRENCY'] || 4)
threads_count = Integer(ENV['THREAD_COUNT'] || 16)
threads threads_count, threads_count

environment ENV['RACK_ENV'] || 'development'
port        ENV['PORT']     || 3000

# daemonize true