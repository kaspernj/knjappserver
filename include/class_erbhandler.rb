require "#{$knjappserver_config["knjrbfw"]}knj/erb/include.rb"

class Knjappserver::ERBHandler
	def initialize
		@connected = false
	end
	
	def erb_handler(data)
		#Hack the Knj::Thread to accept data - this is how get, post and etc. are set.
		Thread.current.data[:knjappserver] = data
		
		eruby = data[:httpsession].eruby
		
		if !@connected
			eruby.connect("error") do |e|
				_kas.handle_error(e)
			end
			
			@connected = true
		end
		
		cont = eruby.load_return(data[:filepath], {
			:with_headers => false,
			:io => data[:httpsession].out,
			:custom_io => true
		})
		headers = eruby.headers
		eruby.reset_headers
		
		data[:httpsession].out.rewind
		cont = data[:httpsession].out.read
		
		headers_ret = {}
		headers.each do |header|
			headers_ret[header[0]] = [header[1]]
		end
		
		Thread.current.data[:knjappserver].clear
		Thread.current.data.delete(:knjappserver)
		
		return {
			:content => cont,
			:headers => headers
		}
	end
end

#Hack to detect we are running KnjEruby
$knj_eruby = KnjEruby