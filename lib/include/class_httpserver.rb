class Knjappserver::Httpserver
  attr_accessor :working_count
	attr_reader :kas, :http_sessions, :thread_accept
	
	def initialize(kas)
		@kas = kas
		@http_sessions = []
		@http_sessions_mutex = Mutex.new
		@working_count = 0
	end
	
	def start
		@server = TCPServer.new(@kas.config[:host], @kas.config[:port])
		
		@thread_accept = Knj::Thread.new do
			loop do
				if !@server or @server.closed?
					sleep 0.5
					next
				end
				
				begin
					self.spawn_httpsession(@server.accept)
					STDOUT.print "Starting new HTTP-request.\n" if @kas.config[:verbose]
				rescue => e
					STDOUT.puts e.inspect
					STDOUT.puts e.backtrace
					STDOUT.print "\n"
					STDOUT.print "Could not accept HTTP-request - waiting 0.5 sec and then trying again.\n"
					sleep 0.5
				end
			end
		end
		
		loop do
			begin
				sleep 30
				socket = TCPSocket.open(@kas.config[:host], @kas.config[:port])
				socket.close
			rescue Interrupt => e
				print "\nStopping appserver.\n"
				exit
			rescue => e
				STDOUT.print "We are not online - restarting HTTP-server!\n"
				
				STDOUT.puts e.inspect if @kas.config[:debug]
				STDOUT.puts e.backtrace if @kas.config[:debug]
				
				begin
					@server.close if @server and !@server.closed?
				rescue Exception => e
					#ignore
				end
				
				STDOUT.print "Starting new server:\n"
				@server = TCPServer.new(@kas.config[:host], @kas.config[:port])
				STDOUT.print "Done.\n"
			end
		end
	end
	
	def stop
		@server.close
	end
	
	def spawn_httpsession(socket)
		@http_sessions_mutex.synchronize do
			@http_sessions << Knjappserver::Httpsession.new(self, socket)
		end
	end
	
	def count_working
		count = 0
		
		@http_sessions_mutex.synchronize do
			@http_sessions.each do |httpsession|
				count += 1 if httpsession and httpsession.working == true and httpsession.active == true
			end
		end
		
		return count
	end
end