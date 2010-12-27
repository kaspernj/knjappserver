class Knjappserver::Httpserver
	attr_reader :kas, :http_sessions
	
	def initialize(kas)
		@kas = kas
		
		@server = TCPServer.new(@kas.config[:host], @kas.config[:port])
		@http_sessions = []
	end
	
	def start
		loop do
			@http_sessions << Knjappserver::Httpsession.new(self, @server.accept)
		end
	end
	
	def stop
		@server.close
	end
end