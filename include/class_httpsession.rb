class Knjappserver::Httpsession
	attr_accessor :data
	attr_reader :session, :session_id, :session_hash, :kas, :working, :active, :out, :db, :cookie, :eruby
	
	def initialize(httpserver, socket)
		@data = {}
		@socket = socket
		@httpserver = httpserver
		@kas = httpserver.kas
		@active = true
		@working = true
		@eruby = Knj::Eruby.new
		
		STDOUT.print "New httpsession #{self.__id__} (total: #{@httpserver.http_sessions.count}).\n" if @kas.config[:debug]
		
		Knj::Thread.new do
			begin
				while @active
					@working = false
					@out = StringIO.new
					req = WEBrick::HTTPRequest.new(WEBrick::Config::HTTP) if @kas.config[:engine_webrick]
					req.parse(@socket)
					
					sleep 0.1 while @kas.paused? #Check if we should be waiting with executing the pending request.
					
					if @kas.config[:max_requests_working]
						sleep 0.1 while @httpserver.count_working > @kas.config[:max_requests_working]
					end
					
					@working = true
					@db = @kas.db_handler.get_and_lock
					raise "Didnt get a database?" if !@db
					self.serve_webrick(req)
					@kas.db_handler.free(@db)
					@db = nil
					@kas.served += 1
					req.fixup if req.keep_alive?
				end
			rescue WEBrick::HTTPStatus::RequestTimeout, WEBrick::HTTPStatus::EOFError
				#Ignore - the user probaly left.
			rescue SystemExit, Interrupt => e
				raise e
			rescue RuntimeError, Exception => e
				bt = e.backtrace
				first = nil
				bt.each do |key, val|
					first = key
					break
				end
				
				if first.index("webrick/httprequest.rb") != nil or first.index("webrick/httpresponse.rb") != nil
					if @kas and @kas.config[:debug]
						STDOUT.print "Notice: Webrick error - properly faulty request - ignoring!\n"
						STDOUT.puts e.inspect
						STDOUT.puts e.backtrace
					end
				else
					STDOUT.puts e.inspect
					STDOUT.puts e.backtrace
				end
			ensure
				if req
					req.destroy
					req = nil
				end
				
				self.close
				self.destruct
			end
		end
	end
	
	def finalize
		STDOUT.print "Httpsession finalize #{self.__id__}.\n"
	end
	
	def destruct
		@thread = nil
		STDOUT.print "Httpsession destruct (#{@httpserver.http_sessions.count})\n" if @kas.config[:debug]
		@httpserver.http_sessions.delete(self)
		
		@httpserver = nil
		@data = nil
		@kas = nil
		@db = nil
		@active = nil
		@working = nil
		@session = nil
		@session_id = nil
		@session_accessor = nil
		@session_hash = nil
		@out = nil
		@socket = nil
		@eruby.destroy if @eruby
		@eruby = nil
	end
	
	def close
		begin
			@socket.close if @socket
		rescue => e
			#ignore if it fails...
		end
	end
	
	def serve_webrick(request)
		err_log = StringIO.new
		res = WEBrick::HTTPResponse.new(
			:HTTPVersion => WEBrick::HTTPVersion.new("1.1")
		)
		res.status = 200
		
		meta = request.meta_vars
		
		page_filepath = meta["PATH_INFO"]
		if page_filepath.length <= 0 or page_filepath == "/"
			page_filepath = @kas.config[:default_page]
		end
		
		STDOUT.print "Serving: #{page_filepath}\n" if @kas and @kas.config[:verbose]
		
		page_path = "#{@kas.config[:doc_root]}/#{page_filepath}"
		pinfo = Knj::Php.pathinfo(page_path)
		ext = pinfo["extension"].downcase
		
		ctype = @kas.config[:default_filetype]
		ctype = @kas.config[:filetypes][ext.to_sym] if @kas.config[:filetypes][ext.to_sym]
		
		calc_id = "#{meta["HTTP_HOST"]}_#{meta["REMOTE_HOST"]}_#{meta["HTTP_X_FORWARDED_SERVER"]}_#{meta["HTTP_X_FORWARDED_FOR"]}_#{meta["HTTP_X_FORWARDED_HOST"]}_#{meta["REMOTE_ADDR"]}_#{meta["HTTP_USER_AGENT"]}".hash
		
		if !@session or !@session_id or calc_id != @session_id
			@session_id = calc_id
			session = @kas.session_fromid(@session_id)
			@session = session[:dbobj]
			@session_hash = session[:hash]
			@session_accessor = @session.accessor
		end
		
		get = Knj::Web.parse_urlquery(meta["QUERY_STRING"])
		post = {}
		cookie = {}
		
		if meta["REQUEST_METHOD"] == "POST"
			self.convert_webrick_post(post, request.query)
		end
		
		request.cookies.each do |cookie_enum|
			cookie[cookie_enum.name] = Knj::Php.urldecode(cookie_enum.value)
		end
		
		serv_data = self.serve_real(
			:filepath => page_path,
			:get => get,
			:post => post,
			:cookie => cookie,
			:meta => meta,
			:request => request,
			:headers => {},
			:host => meta["HTTP_HOST"],
			:ctype => ctype,
			:ext => ext,
			:session => @session,
			:session_id => @session_id,
			:session_accessor => @session_accessor,
			:session_hash => @session_hash,
			:httpsession => self,
			:request => request,
			:db => @db,
			:kas => @kas
		)
		
		STDOUT.print Knj::Php.print_r(serv_data[:headers], true)
		
		serv_data[:headers].each do |key, valarr|
			valarr.each do |val|
				keystr = key.to_s.strip.downcase
				
				if keystr.match(/^set-cookie/)
					WEBrick::Cookie.parse_set_cookies(val).each do |cookie|
						res.cookies << cookie
					end
				elsif keystr.match(/^content-type/i)
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
		res.destroy
		
		#Letting them be nil is simply not enough (read that on a forum) - knj.
		get.clear
		post.clear
		meta.clear
		cookie.clear
		serv_data.clear
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
					ret = handler_info[:callback].call(details)
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
					raise "Could not figure out how to use handler."
				end
				
				break
			end
		end
		
		if !handler_found
			if !File.exists?(details[:filepath])
				statuscode = 404
			else
				lastmod = Knj::Datet.new(File.new(details[:filepath]).mtime)
				
				if cache_use and request.header["if-modified-since"] and request.header["if-modified-since"][0]
					request_mod = Knj::Datet.parse(request.header["if-modified-since"][0])
					if request_mod == lastmod
						cache = true
					end
				end
				
				if !cache
					cont = Knj::Php.file_get_contents(details[:filepath]) #get plain content from file.
				end
			end
		end
		
		details.clear
		
		return {
			:statuscode => statuscode,
			:content => cont,
			:headers => headers,
			:lastmod => lastmod,
			:cache => cache
		}
	end
end