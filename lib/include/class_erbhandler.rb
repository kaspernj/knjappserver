class Knjappserver::ERBHandler
	def initialize
		@connected = {}
	end
	
	def erb_handler(data)
		#Hack the Knj::Thread to accept data - this is how get, post and etc. are set.
		Thread.current[:knjappserver] = data
		eruby = data[:httpsession].eruby
		
		if !@connected[eruby.__id__]
			eruby.connect("error") do |e|
				_kas.handle_error(e)
			end
			
			@connected[eruby.__id__] = true
		end
		
		cont = eruby.load_return(data[:filepath], {
			:with_headers => false,
			:custom_io => true
		})
		headers = eruby.headers
		eruby.reset_headers
		
		headers_ret = {}
		headers.each do |header|
			headers_ret[header[0]] = [header[1]]
		end
		
		Thread.current[:knjappserver].clear
    Thread.current[:knjappserver] = nil
		
    return {:headers => headers}
	end
end