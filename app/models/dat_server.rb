# Wrapper for starting, stopping, and checking on the daemon for a given
# dat repository's server
class DatServer

  attr_accessor :server_name, :http_port, :dat_repository, :pid_file

  # @param [DatRepo] dat_repository to serve
  def initialize(dat_repository, server_name: nil, http_port: "8080")
    raise ArgumentError, "you must provide a DatRepository object" unless dat_repository.instance_of?(DatRepository)
    @dat_repository = dat_repository
    @server_name = server_name ? server_name : dat_repository.identifier
    @http_port = http_port
    @pid_file = "tmp/pids/dat_servers/#{@server_name}.pid"
    @log_file = "tmp/pids/dat_servers/#{@server_name}.log"
    setup_env
  end

  # Start the server daemon
  def start
    # Example of the commmand that is run
    # command = "/Users/matt/Develop/bindery/databindery-api-server/node_modules/.bin/taco-nginx --name foo --http-port 8080 --https-port 8443 dat serve"
    command = "#{taco_nginx_path} --name #{server_name} --http-port #{http_port} --https-port 8443 dat serve"
    pid = Process.spawn(command, {chdir: dat_repository.dir, out: @log_file, err: @log_file})
    File.open(@pid_file, 'w') { |file| file.write(pid) }
    pid.to_s
  end

  # Stop the server daemon
  def stop
    kill_process
  end

  # pid of the server daemon (if it's running)
  def pid
    return nil unless File.exists?(@pid_file)
    begin
      value_from_file = File.read(@pid_file)
    rescue Errno::ENOENT
      return nil
    end

    if /\A\d+\z/.match(value_from_file)
      return value_from_file.to_i
    else
      return nil
    end
  end

  # check if the pid file is pointing to a running process
  def pid_valid?
    return false unless pid
    begin
      Process.kill(0, pid)
      return true
    rescue Errno::EPERM
      return true
    rescue Errno::ESRCH
      return false
    end
  end

  def cleanup_invalid_pid_file
    File.delete(@pid_file) if File.exists?(@pid_file) && !pid_valid?
  end

  # check if the server is responding properly
  def server_running?
    # have to rely on nginx_port, which is a bit unstable,
    # because we're not setting up hostnames for each dat server,
    # so we can't just ping "#{@server_name}.localhost:#{@http_port}"
    begin
      response = Net::HTTP.get('localhost', '/', nginx_port)
      # make sure the response is actually info from a dat server
      return response.include? '"datasets":['
    rescue Errno::ECONNREFUSED
      return false
    end
  end

  def hostname
    "#{@server_name}.localhost:#{@http_port}"
  end

  # Returns the port that nginx should be running the daemon at
  def nginx_port
    log_line = File.readlines(@log_file)[-1]
    if log.include?("Listening on port")
      log_line.split(' ').last
    else
      nil
    end
  end

  private

  def taco_nginx_path
    File.join(Rails.root, 'node_modules/.bin/taco-nginx')
  end

  def setup_env
    FileUtils.mkdir_p('tmp/pids/dat_servers')
    FileUtils.touch('log/dat_servers.log')
  end

  def kill_process
    begin
      Process.kill('SIGTERM', pid) if pid
    rescue Errno::ESRCH
      # process wasn't running.  Do nothing.
    end
    # Delete the pid file unless the process is still running for some reason
    if File.exists?(@pid_file)
      File.delete(@pid_file) unless pid_valid?
    end
  end

end