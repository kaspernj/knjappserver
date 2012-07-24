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
            if @debug
              STDOUT.puts e.inspect
              STDOUT.puts e.backtrace
              STDOUT.print "\n"
              STDOUT.print "Could not accept HTTP-request - waiting 1 sec and then trying again.\n"
            end
            
            sleep 1
          end
        end
      rescue => e
        STDOUT.print Knj::Errors.error_str(e)
      end
		end
	end
	
	def stop
    STDOUT.print "Stopping accept-thread.\n" if @debug
    @thread_accept.kill if @thread_accept and @thread_accept.alive?
    @thread_restart.kill if @thread_restart and @thread_restart.alive?
    
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
	
	def count_block
    begin
      added = false
      @mutex_count.synchronize do
        @working_count += 1 if @working_count != nil
        added = true
      end
      
      yield
    ensure
      @kas.served += 1 if @kas
      
      @mutex_count.synchronize do
        @working_count -= 1 if @working_count != nil and added
      end
    end
	end
end