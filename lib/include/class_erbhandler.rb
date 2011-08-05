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
		cookies = eruby.cookies
		eruby.reset_headers
		
		Thread.current[:knjappserver].clear
    Thread.current[:knjappserver] = nil
		
		raise "No headers given." if !headers
    raise "No cookies given." if !cookies
		
    return {:headers => headers, :cookies => cookies}
	end
end