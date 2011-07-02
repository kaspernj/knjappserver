class Knjappserver::Httpsession::Webrick
	attr_reader :get, :post, :cookie, :meta, :page_path, :headers
	
	def initialize(args)
		@args = args
		@kas = @args[:kas]
	end
	
	def socket_parse(socket)
		req = WEBrick::HTTPRequest.new(WEBrick::Config::HTTP)
		req.parse(socket)
		
		
		#Set meta.
		@meta = req.meta_vars
		
		
		#Set page_path.
		page_filepath = meta["PATH_INFO"]
		if page_filepath.length <= 0 or page_filepath == "/" or File.directory?("#{@kas.config[:doc_root]}/#{page_filepath}")
			page_filepath = "#{page_filepath}/#{@kas.config[:default_page]}"
		end
		
		@page_path = "#{@kas.config[:doc_root]}/#{page_filepath}"
		
		
		#Set get and headers.
		@get = Knj::Web.parse_urlquery(@meta["QUERY_STRING"])
		@headers = req.header
		
		
		#Set post.
		@post = {}
		if meta["REQUEST_METHOD"] == "POST"
			self.convert_webrick_post(@post, req.query)
		end
		
		
		#Set cookie.
		@cookie = {}
		
		req.cookies.each do |cookie_enum|
			@cookie[cookie_enum.name] = CGI.unescape(cookie_enum.value)
		end
		
		
		req.fixup if req and req.keep_alive?
	end
	
	def convert_webrick_post(seton, webrick_post, args = {})
		webrick_post.each do |varname, value|
			Knj::Web.parse_name(seton, varname, value, args)
		end
	end
	
	def destroy
		@args.clear if @args
		@args = nil
		@kas = nil
		
		@meta.clear if @meta
		@meta = nil
		
		@page_path = nil
		
		@get.clear if @get
		@get = nil
		
		@post.clear if @post
		@post = nil
		
		@cookie.clear if @cookie
		@cookie = nil
	end
end