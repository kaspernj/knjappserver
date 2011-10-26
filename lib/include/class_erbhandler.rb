class Knjappserver::ERBHandler
	def initialize
		@connected = {}
	end
	
	def erb_handler(httpsess, eruby)
		if !@connected[eruby.__id__]
			eruby.connect("error") do |e|
				_kas.handle_error(e)
			end
			
			@connected[eruby.__id__] = true
		end
		
		eruby.load_return(httpsess.page_path, {
			:with_headers => false,
			:custom_io => true
		})
	end
end