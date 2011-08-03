class Knjappserver::Httpserver
  attr_accessor :working_count
	attr_reader :kas, :http_sessions, :thread_accept, :thread_restart, :server
	
	def initialize(kas)
		@kas = kas
		@http_sessions = []
		@working_count = 0
	end
	
	def start
    raise "No host was given." if !@kas.config.has_key?(:host)
    raise "No port was given." if !@kas.config.has_key?(:port)
		@server = TCPServer.new(@kas.config[:host], @kas.config[:port])
		
		@thread_accept = Knj::Thread.new do
			loop do
				if !@server or @server.closed?
					sleep 1
					next
				end
				
				begin
					self.spawn_httpsession(@server.accept)
					STDOUT.print "Starting new HTTP-request.\n" if @kas.config[:debug]
				rescue => e
					STDOUT.puts e.inspect
					STDOUT.puts e.backtrace
					STDOUT.print "\n"
					STDOUT.print "Could not accept HTTP-request - waiting 0.5 sec and then trying again.\n"
					sleep 0.5
				end
			end
		end
		
		@thread_restart = Knj::Thread.new do
      loop do
        sleep 10
        break if @kas.should_restart and @kas.should_restart_done
        
        if !@kas.should_restart and (!@server or @server.closed?)
          STDOUT.print "Socket does not exist or is closed - restarting HTTP-server!\n"
          @server = TCPServer.new(@kas.config[:host], @kas.config[:port])
          STDOUT.print "Done.\n"
        end
      end
    end
	end
	
	def stop
    begin
      STDOUT.print "Stopping accept-thread.\n" if @kas.config[:debug]
      @thread_accept.kill if @thread_accept and @thread_accept.alive?
      @thread_restart.kill if @thread_restart and @thread_restart.alive?
    rescue => e
      STDOUT.print "Could not stop accept-thread.\n" if @kas.config[:debug]
      STDOUT.puts e.inspect
      STDOUT.puts e.backtrace
    end
    
    STDOUT.print "Stopping all HTTP sessions.\n" if @kas.config[:debug]
    @http_sessions.each do |httpsession|
      httpsession.destruct
    end
    
    begin
      STDOUT.print "Stopping TCPServer.\n" if @kas.config[:debug]
      @server.close if @server and !@server.closed?
      STDOUT.print "TCPServer was closed.\n" if @kas.config[:debug]
    rescue Timeout::Error
      raise "Could not close TCPserver.\n"
    rescue IOError => e
      if e.message == "closed stream"
        #ignore - it should be closed.
      else
        raise e
      end
    end
	end
	
	def spawn_httpsession(socket)
    @http_sessions << Knjappserver::Httpsession.new(self, socket)
	end
	
	def handle_request(&block)
    @working_count += 1
    begin
      block.call
    ensure
      @working_count -= 1
    end
	end
end