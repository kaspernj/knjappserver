class Knjappserver::Httpsession
	attr_accessor :data
	attr_reader :session, :session_id, :session_hash, :kas, :working, :active, :out, :db, :cookie, :get, :post, :meta, :eruby
	
	def initialize(httpserver, socket)
		@data = {}
		@socket = socket
		@httpserver = httpserver
		@kas = httpserver.kas
		@active = true
		@working = true
		@eruby = Knj::Eruby.new
		@self_var = self
		
		require "webrick"
		
		Knj::Thread.new do
			begin
				while @active
					@working = false
					
					if @kas.config[:engine_webrick]
						@out = StringIO.new
						req = WEBrick::HTTPRequest.new(WEBrick::Config::HTTP) if @kas.config[:engine_webrick]
						req.parse(@socket)
						
						# Check if we should be waiting with executing the pending request.
						sleep 0.1 while @kas.paused?
						
						if @kas.config[:max_requests_working]
							sleep 0.1 while @httpserver.count_working > @kas.config[:max_requests_working]
						end
						
						@working = true
						
						@db = @kas.db_handler.get_and_lock
						self.serve_webrick(req)
						@kas.db_handler.free(@db)
						@db = nil
						req = nil
						@kas.served += 1
					else
						req_read = ""
						
						while @active
							req_read += @socket.gets if @active
							
							if req_read.slice(-2, 2) == "\n\n" or req_read.slice(-4, 4) == "\r\n\r\n"
								self.serve_internal(req_read)
								break
							end
						end
					end
				end
				
				break
			rescue WEBrick::HTTPStatus::RequestTimeout, WEBrick::HTTPStatus::EOFError
				#Ignore - the user probaly left.
			rescue => e
				STDOUT.puts e.inspect
				STDOUT.puts e.backtrace
				
				if e.message == "Corruption!"
					exit
				end
			ensure
				self.close
				self.destruct
			end
		end
	end
	
	def destruct
		@httpserver.http_sessions.delete(self)
		@httpserver = nil
		@data = nil
		@kas = nil
		@active = nil
		@working = nil
		@session = nil
		@session_id = nil
		@out = nil
		@cookie = nil
		@get = nil
		@post = nil
		@socket = nil
		@eruby = nil
	end
	
	def close
		@socket.close if @socket
	end
	
	def serve_webrick(request)
		res = WEBrick::HTTPResponse.new({
			:HTTPVersion => WEBrick::HTTPVersion.new("1.1")
		})
		res.status = 200
		
		@meta = request.meta_vars
		
		page_filepath = @meta["PATH_INFO"]
		if page_filepath.length <= 0 or page_filepath == "/"
			page_filepath = @kas.config[:default_page]
		end
		
		page_path = "#{@kas.config[:doc_root]}/#{page_filepath}"
		pinfo = Php.pathinfo(page_path)
		ext = pinfo["extension"].downcase
		
		ctype = @kas.config[:default_filetype]
		ctype = @kas.config[:filetypes][ext.to_sym] if @kas.config[:filetypes][ext.to_sym]
		
		calc_id = Php.md5("#{@meta["HTTP_HOST"]}_#{@meta["REMOTE_HOST"]}_#{@meta["HTTP_X_FORWARDED_SERVER"]}_#{@meta["HTTP_X_FORWARDED_FOR"]}_#{@meta["HTTP_X_FORWARDED_HOST"]}_#{@meta["REMOTE_ADDR"]}_#{@meta["HTTP_USER_AGENT"]}")
		
		if !@session or !@session_id or calc_id != @session_id
			@session_id = calc_id
			session = @kas.session_fromid(@session_id)
			@session = session[:dbobj]
			@session_hash = session[:hash]
			@session_accessor = @session.accessor
		end
		
		@get = Web.parse_urlquery(@meta["QUERY_STRING"])
		@post = {}
		@cookie = {}
		
		if meta["REQUEST_METHOD"] == "POST"
			self.convert_webrick_post(@post, request.query)
		end
		
		request.cookies.each do |cookie|
			@cookie[cookie.name] = Php.urldecode(cookie.value)
		end
		
		serv_data = self.serve_real(
			:meta => @meta,
			:request => request,
			:headers => {},
			:page_path => page_path,
			:host => @meta["HTTP_HOST"],
			:ctype => ctype,
			:ext => ext
		)
		
		serv_data[:headers].each do |key, valarr|
			valarr.each do |val|
				if key.to_s.strip.downcase.match(/^set-cookie/i)
					WEBrick::Cookie.parse_set_cookies(val).each do |cookie|
						res.cookies << cookie
					end
				elsif key.to_s.strip.downcase.match(/^content-type/i)
					raise "Could not parse content-type: '#{val}'." if !match = val.match(/^(.+?)(;|$)/)
					ctype = match[1]
				else
					res.header[key] = val
				end
			end
		end
		
		res.content_type = ctype
		res.body = serv_data[:content]
		
		if serv_data[:lastmod]
			res["Last-Modified"] = serv_data[:lastmod].time
			res["Expires"] = Time.now + (3600 * 24)
		end
		
		if serv_data[:cache]
			res.status = 304
			res["Last-Modified"] = serv_data[:lastmod].time
			res["Expires"] = Time.now + (3600 * 24)
		end
		
		if serv_data[:statuscode]
			res.status = serv_data[:statuscode]
		end
		
		res.send_response(@socket)
	end
	
	def convert_webrick_post(seton, webrick_post, args = {})
		webrick_post.each do |varname, value|
			if value.respond_to?(:filename) and value.filename
				realvalue = value
			else
				realvalue = value.to_s
			end
			
			if match = varname.match(/(.+)\[(.*?)\]/)
				namepos = varname.index(match[0])
				name = match[1]
				secname, secname_empty = Web.parse_secname(seton, match[2], args)
				valuefrom = namepos + match[1].length + 2
				restname = varname.slice(valuefrom..-1)
				seton[name] = {} if !seton.has_key?(name)
				
				if restname and restname.index("[") != nil
					seton[name][secname] = {} if !seton.has_key?(secname)
					self.convert_webrick_post(seton[secname], restname, value, args)
				else
					seton[name][secname] = realvalue
				end
			else
				seton[varname] = realvalue
			end
		end
	end
	
	def convert_webrick_post_second
		webrick_post.each do |varname, value|
			if value.respond_to?(:filename) and value.filename
				realvalue = value
			else
				realvalue = value.to_s
			end
			
			if match = varname.match(/\[(.*?)\]/)
				namepos = varname.index(match[0])
				name = match[1]
				secname, secname_empty = Web.parse_secname(seton, match[1], args)
				valuefrom = namepos + match[1].length + 2
				restname = varname.slice(valuefrom..-1)
				
				if restname and restname.index("[") != nil
					seton[secname] = {} if !seton.has_key?(secname)
					self.convert_webrick_post(seton[secname], restname, value, args)
				else
					seton[secname] = realvalue
				end
			else
				seton[varname] = realvalue
			end
		end
	end
	
	def serve_internal(request)
		match = request.match(/^GET (.+) HTTP\/1\.1\s*/)
		raise "Could not parse request." if !match
		
		headers = {}
		request = request.gsub(match[0], "")
		request.scan(/(\S+):\s*(.+)\r\n/) do |header_match|
			headers[header_match[0].downcase] = header_match[1]
		end
		
		keepalive = 0
		keepalive = headers["keep-alive"].to_i if headers["keep-alive"] and Php.is_numeric(headers["keep-alive"])
		
		if match[1] == "/"
			page = @kas.config[:default_page]
		elsif match
			page = match[1]
		end
		
		mainheader = "HTTP/1.1 200/OK\r\n"
		page_path = "#{@kas.config[:doc_root]}/#{page}"
		
		if File.exists?(page_path)
			cont = Php.file_get_contents(page_path)
		else
			mainheader = "HTTP/1.1 404/Not Found\r\n"
			cont = ""
		end
		
		if headers["host"]
			host = headers["host"]
		elsif @kas.config[:hostname]
			host = @kas.config[:hostname]
		else
			raise "Could not figure out a valid hostname."
		end
		
		ctype = @kas.config[:default_filetype]
		pinfo = Php.pathinfo(page_path)
		ext = pinfo["extension"].downcase
		ctype = @kas.config[:filetypes][ext] if @kas.config[:filetypes][ext]
		
		cont = self.serve_real(
			:page_path => page_path,
			:host => host,
			:ctype => ctype,
			:ext => ext
		)
		headers = {
			"Host" => [details[:host]],
			"Content-Type" => [details[:ctype]],
			"Content-Length" => [cont.length]
		}
		
		headers_str = "#{mainheader}\r\n"
		headers.each do |key, valarr|
			valarr.each do |val|
				headers_str += "#{key}: #{val}\r\n"
			end
		end
		headers_str += "\r\n"
		
		@socket.write headers_str + cont + "\r\n"
		
		doclose = false
		doclose = true if keepalive <= 0
		doclose = true if headers["connection"] == "close"
		
		self.close if doclose
	end
	
	def serve_real(details)
		request = details[:request]
		headers = {}
		cont = ""
		statuscode = nil
		handler_found = false
		lastmod = false
		max_age = 365 * 24
		
		cache = false
		cache_control = {}
		cache_use = true
		
		if request.header["cache-control"] and request.header["cache-control"][0]
			request.header["cache-control"][0].scan(/(.+)=(.+)/) do |match|
				cache_control[match[1]] = match[2]
			end
		end
		
		#cache_use = false if cache_control["max-age"].to_i <= 0
		
		#check if we should use a handler for this request.
		@kas.config[:handlers].each do |handler_info|
			handler_use = false
			
			if handler_info[:file_ext] and handler_info[:file_ext] == details[:ext]
				handler_use = true
				handler_found = true
			end
			
			if handler_use
				if handler_info[:callback]
					ret = handler_info[:callback].call({
						:get => @get,
						:post => @post,
						:cookie => @cookie,
						:httpsession => self,
						:session => @session,
						:session_id => @session_id,
						:session_accessor => @session_accessor,
						:session_hash => @session_hash,
						:request => request,
						:meta => details[:meta],
						:filepath => details[:page_path],
						:db => @db,
						:kas => @kas,
						:server => {
							:host => details[:host],
							:keepalive => details[:keepalive],
							:headers => details[:headers]
						}
					})
					cont = ret[:content] if ret[:content]
					
					if ret[:headers]
						ret[:headers].each do |key, valarr|
							valarr.each do |val|
								headers[key] << val if headers[key]
								headers[key] = [val] if !headers[key]
							end
						end
					end
				else
					raise "Could not figure out to use handler."
				end
				
				break
			end
		end
		
		if !handler_found
			if !File.exists?(details[:page_path])
				statuscode = 404
			else
				lastmod = Datet.new(File.new(details[:page_path]).mtime)
				
				if cache_use and request.header["if-modified-since"] and request.header["if-modified-since"][0]
					request_mod = Datet.parse(request.header["if-modified-since"][0])
					if request_mod == lastmod
						cache = true
					end
				end
				
				if !cache
					cont = Php.file_get_contents(details[:page_path]) #get plain content from file.
				end
			end
		end
		
		return {
			:statuscode => statuscode,
			:content => cont,
			:headers => headers,
			:lastmod => lastmod,
			:cache => cache
		}
	end
end