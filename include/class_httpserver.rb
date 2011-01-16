class Knjappserver::Httpserver
	attr_reader :kas, :http_sessions
	
	def initialize(kas)
		@kas = kas
		@http_sessions = []
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
					@http_sessions << Knjappserver::Httpsession.new(self, @server.accept)
					STDOUT.print "Starting new HTTP-request.\n" if @kas.config[:verbose]
				rescue => e
					STDOUT.print "Could not accept HTTP-request - waiting 0.5 sec and then trying again.\n"
					sleep 0.5
				end
			end
		end
		
		loop do
			sleep 2
			STDOUT.print "Checking if we are online.\n" if @kas.config[:debug]
			
			begin
				socket = TCPSocket.open(@kas.config[:host], @kas.config[:port])
				socket.close
			rescue => e
				STDOUT.print "We are not online - restarting HTTP-server!\n"
				
				STDOUT.puts e.inspect if @kas.config[:debug]
				STDOUT.puts e.backtrace if @kas.config[:debug]
				
				begin
					@server.close if @server and !@server.closed?
				rescue Exception => e
					#ignore
				end
				
				print "Starting new server:\n"
				@server = TCPServer.new(@kas.config[:host], @kas.config[:port])
				print "Done.\n"
			end
		end
	end
	
	def stop
		@server.close
	end
	
	def count_working
		count = 0
		@http_sessions.clone.each do |httpsession|
			count += 1 if httpsession.working
		end
		
		return count
	end
end