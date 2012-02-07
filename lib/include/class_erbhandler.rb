class Knjappserver::ERBHandler
	def initialize
		@connected = {}
	end
	
	def erb_handler(httpsess)
    eruby = httpsess.eruby
    
		if !@connected.key?(eruby.__id__)
			eruby.connect("error") do |e|
				_kas.handle_error(e)
			end
			
			@connected[eruby.__id__] = true
		end
		
		if !File.exists?(httpsess.page_path)
      eruby.import("#{File.dirname(__FILE__)}/../pages/error_notfound.rhtml")
    else
      eruby.import(httpsess.page_path)
    end
    
    httpsess.resp.status = 500 if eruby.error
	end
end