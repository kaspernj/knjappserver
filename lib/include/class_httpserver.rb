class Knjappserver::Httpserver
  attr_accessor :working_count
	attr_reader :kas, :http_sessions, :thread_accept, :thread_restart, :server
	
	def initialize(kas)
		@kas = kas
		@debug = @kas.config[:debug]
		@mutex_count = Mutex.new
	end
	
	def start
    @http_sessions = []
    @working_count = 0
    
    raise "No host was given." if @kas and !@kas.config.has_key?(:host)
    raise "No port was given." if @kas and !@kas.config.has_key?(:port)
		@server = TCPServer.new(@kas.config[:host], @kas.config[:port])
		
		@thread_accept = Thread.new do
      begin
        loop do
          if !@server or @server.closed?
            sleep 1
            next
          end
          
          begin
            self.spawn_httpsession(@server.accept)
            STDOUT.print "Starting new HTTP-request.\n" if @debug
          rescue => e
            STDOUT.puts e.inspect
            STDOUT.puts e.backtrace
            STDOUT.print "\n"
            STDOUT.print "Could not accept HTTP-request - waiting 1 sec and then trying again.\n"
            sleep 1
          end
        end
      rescue => e
        STDOUT.print Knj::Errors.error_str(e)
      end
		end
		
		@thread_restart = Thread.new do
      begin
        loop do
          sleep 10
          break if @kas.should_restart and @kas.should_restart_done
          
          if !@kas.should_restart and (!@server or @server.closed?)
            STDOUT.print "Socket does not exist or is closed - restarting HTTP-server!\n"
            @server = TCPServer.new(@kas.config[:host], @kas.config[:port])
            STDOUT.print "Done.\n"
          end
        end
      rescue => e
        if @kas
          @kas.handle_error(e)
        else
          STDOUT.print Knj::Errors.error_str(e)
        end
      end
    end
	end
	
	def stop
    begin
      STDOUT.print "Stopping accept-thread.\n" if @debug
      @thread_accept.kill if @thread_accept and @thread_accept.alive?
      @thread_restart.kill if @thread_restart and @thread_restart.alive?
    rescue => e
      STDOUT.print "Could not stop threads.\n" if @debug
      STDOUT.puts e.inspect
      STDOUT.puts e.backtrace
    end
    
    STDOUT.print "Stopping all HTTP sessions.\n" if @debug
    if @http_sessions
      @http_sessions.each do |httpsession|
        httpsession.destruct
      end
    end
    
    begin
      STDOUT.print "Stopping TCPServer.\n" if @debug
      @server.close if @server and !@server.closed?
      STDOUT.print "TCPServer was closed.\n" if @debug
    rescue Timeout::Error
      raise "Could not close TCPserver.\n"
    rescue IOError => e
      if e.message == "closed stream"
        #ignore - it should be closed.
      else
        raise e
      end
    end
    
    @http_sessions = nil
    @thread_accept = nil
    @thread_restart = nil
    @server = nil
    @working_count = nil
    @kas = nil
	end
	
	def spawn_httpsession(socket)
    @http_sessions << Knjappserver::Httpsession.new(self, socket)
	end
	
	def count_add
    @mutex_count.synchronize do
      @working_count += 1 if @working_count
    end
	end
	
	def count_remove
    @mutex_count.synchronize do
      @working_count -= 1 if @working_count
    end
	end
end