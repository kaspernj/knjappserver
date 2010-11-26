class Knjappserver::Httpsession
	def initialize(httpserver, socket)
		@socket = socket
		@httpserver = httpserver
		@kas = httpserver.kas
		@active = true
		
		require "webrick"
		
		Knj::Thread.new do
			begin
				while @active
					if @kas.config[:engine_webrick]
						req = WEBrick::HTTPRequest.new(WEBrick::Config::HTTP) if @kas.config[:engine_webrick]
						req.parse(@socket)
						self.serve_webrick(req)
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
			rescue WEBrick::HTTPStatus::RequestTimeout => e
				self.close
			end
		end
	end
	
	def serve_webrick(request)
		res = WEBrick::HTTPResponse.new({
			:HTTPVersion => WEBrick::HTTPVersion.new("1.1")
		})
		res.status = 202
		
		meta = request.meta_vars
		
		page_filepath = meta["PATH_INFO"]
		if page_filepath.length <= 0 or page_filepath == "/"
			page_filepath = @kas.config[:default_page]
		end
		
		print "Page-filepath: #{page_filepath}\n"
		
		page_path = "#{@kas.config[:doc_root]}/#{page_filepath}"
		pinfo = Php.pathinfo(page_path)
		ext = pinfo["extension"].downcase
		
		ctype = @kas.config[:default_filetype]
		ctype = @kas.config[:filetypes][ext.to_sym] if @kas.config[:filetypes][ext.to_sym]
		res.content_type = ctype
		
		@get = Web.parse_urlquery(meta["QUERY_STRING"])
		@post = {}
		
		if meta["REQUEST_METHOD"] == "POST"
			self.convert_webrick_post(@post, request.query)
		end
		
		serv_data = self.serve_real(
			:request => request,
			:headers => {},
			:page_path => page_path,
			:host => meta["HTTP_HOST"],
			:ctype => ctype,
			:ext => ext
		)
		
		serv_data[:headers].each do |key,valarr|
			valarr.each do |val|
				if key.to_s.strip.downcase.match(/^Set-Cookie/i)
					if !match = val.match(/^(.+):\s*(.+)(;|$)/)
						raise "Could not parse cookie: #{val}"
					end
					
					cookie = WEBrick::Cookie.new(match[0], match[1])
					res.cookies << cookie
				else
					res.header[key] = val
				end
			end
		end
		
		if @kas.config[:debug]
			Php.print_r(request.header)
			print "Ext: #{ext}\n"
			print "Path: #{page_path}\n"
			print "CType: #{ctype}\n"
			print "\n"
		end
		
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
			match = varname.match(/(.+)\[(.*?)\]/)
			if match
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
					seton[name][secname] = value
				end
			else
				seton[name] = value
			end
		end
	end
	
	def convert_webrick_post_second()
		webrick_post.each do |varname, value|
			match = varname.match(/\[(.*?)\]/)
			if match
				namepos = varname.index(match[0])
				name = match[1]
				secname, secname_empty = Web.parse_secname(seton, match[1], args)
				valuefrom = namepos + match[1].length + 2
				restname = varname.slice(valuefrom..-1)
				
				if restname and restname.index("[") != nil
					seton[secname] = {} if !seton.has_key?(secname)
					self.convert_webrick_post(seton[secname], restname, value, args)
				else
					seton[secname] = value
				end
			else
				seton[varname] = value
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
					ret = Php.call_user_func(handler_info[:callback], {
						:get => @get,
						:post => @post,
						:request => request,
						:session => self,
						:filepath => details[:page_path],
						:server => {
							:host => details[:host],
							:keepalive => details[:keepalive],
							:headers => details[:headers]
						}
					})
					cont = ret[:content] if ret[:content]
					
					if ret[:headers]
						ret[:headers].each do |key, val|
							details[:headers][key] << val if headers[key]
							details[:headers][key] = [val] if !headers[key]
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
	
	def close
		@socket.close if @socket
		@socket = nil
		@httpserver = nil
		@kas = nil
		@active = nil
	end
end