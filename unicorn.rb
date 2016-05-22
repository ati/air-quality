@dir = File.expand_path(File.dirname(__FILE__))
worker_processes (ENV['RAILS_ENV'] == 'production' ? 4 : 2)
working_directory @dir

timeout 30

# Specify path to socket unicorn listens to, 
# # we will use this in our nginx.conf later
listen "#{@dir}/tmp/sockets/unicorn.sock", :backlog => 64
#
# # Set process id path
pid "#{@dir}/tmp/pids/unicorn.pid"
#
# # Set log file paths
stderr_path "#{@dir}/logs/unicorn.stderr.log"
stdout_path "#{@dir}/logs/unicorn.stdout.log"

timeout 300

# Load the app up before forking.
preload_app true

# Garbage collection settings.
GC.respond_to?(:copy_on_write_friendly=) &&
  GC.copy_on_write_friendly = true
