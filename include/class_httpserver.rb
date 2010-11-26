class Knjappserver::Httpserver
	attr_reader :kas
	
	def initialize(kas)
		@kas = kas
		
		@server = TCPServer.new(@kas.config[:host], @kas.config[:port])
		@sessions = []
	end
	
	def start
		loop do
			@sessions << Knjappserver::Httpsession.new(self, @server.accept)
		end
	end
end