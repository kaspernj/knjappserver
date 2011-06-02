class Knjappserver::Httpsession
	attr_accessor :data
	attr_reader :session, :session_id, :session_hash, :kas, :working, :active, :out, :db, :cookie, :eruby, :browser
	
	def initialize(httpserver, socket)
		@data = {}
		@socket = socket
		@httpserver = httpserver
		@kas = httpserver.kas
		@active = true
		@working = true
		@eruby = Knj::Eruby.new
		
		ObjectSpace.define_finalizer(self, self.class.method(:finalize).to_proc) if @kas.config[:debug]
		STDOUT.print "New httpsession #{self.__id__} (total: #{@httpserver.http_sessions.count}).\n" if @kas.config[:debug]
		
		Knj::Thread.new do
			begin
				while @active
					begin
						@working = false
						@out = StringIO.new
						req = WEBrick::HTTPRequest.new(WEBrick::Config::HTTP) if @kas.config[:engine_webrick]
						req.parse(@socket)
						
						sleep 0.1 while @kas.paused? #Check if we should be waiting with executing the pending request.
						
						if @kas.config[:max_requests_working]
							sleep 0.1 while @httpserver.count_working > @kas.config[:max_requests_working]
						end
						
						Dir.chdir(@kas.config[:doc_root])
						@working = true
						@db = @kas.db_handler.get_and_lock
						raise "Didnt get a database?" if !@db
						self.serve_webrick(req)
					ensure
						if @db
							@kas.db_handler.free(@db)
							@db = nil
						end
						
						@kas.served += 1
						req.fixup if req and req.keep_alive?
					end
				end
				
				break
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
	
	def self.finalize(id)
		STDOUT.print "Httpsession finalize #{id}.\n" if @kas.config[:debug]
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
		@browser = nil
	end
	
	def close
		begin
			@socket.close if @socket
		rescue => e
			#ignore if it fails...
		end
	end
	
	def serve_webrick(request)
		res = WEBrick::HTTPResponse.new({
			:HTTPVersion => WEBrick::HTTPVersion.new("1.1")
		})
		res.status = 200
		
		meta = request.meta_vars
		
		page_filepath = meta["PATH_INFO"]
		if page_filepath.length <= 0 or page_filepath == "/" or File.directory?("#{@kas.config[:doc_root]}/#{page_filepath}")
			page_filepath = "#{page_filepath}/#{@kas.config[:default_page]}"
		end
		
		page_path = "#{@kas.config[:doc_root]}/#{page_filepath}"
		pinfo = Knj::Php.pathinfo(page_path)
		ext = pinfo["extension"].downcase
		
		ctype = @kas.config[:default_filetype]
		ctype = @kas.config[:filetypes][ext.to_sym] if @kas.config[:filetypes][ext.to_sym]
		
		get = Knj::Web.parse_urlquery(meta["QUERY_STRING"])
		post = {}
		cookie = {}
		
		if meta["REQUEST_METHOD"] == "POST"
			self.convert_webrick_post(post, request.query)
		end
		
		request.cookies.each do |cookie_enum|
			cookie[cookie_enum.name] = CGI.unescape(cookie_enum.value)
		end
		
		@browser = Knj::Web.browser(meta)
		@ip = nil
		@ip = meta["HTTP_X_FORWARDED_FOR"].split(",")[0].strip if !@ip and meta["HTTP_X_FORWARDED_FOR"]
		@ip = meta["REMOTE_ADDR"] if !@ip and meta["REMOTE_ADDR"]
		
		@ips = [meta["REMOTE_ADDR"]]
		@ips << meta["HTTP_X_FORWARDED_FOR"].split(",")[0].strip if meta["HTTP_X_FORWARDED_FOR"]
		
		if @browser["browser"] == "bot"
			@session_id = "bot"
			session = @kas.session_fromid(:idhash => @session_id, :ip => @ip)
		elsif cookie["KnjappserverSession"].to_s.length > 0 and @kas.has_session?(:idhash => cookie["KnjappserverSession"].to_s, :ip => @ip)
			@session_id = cookie["KnjappserverSession"]
			session = @kas.session_fromid(:idhash => @session_id, :ip => @ip)
		else
			calc_id = Digest::MD5.hexdigest("#{Time.new.to_f}_#{meta["HTTP_HOST"]}_#{meta["REMOTE_HOST"]}_#{meta["HTTP_X_FORWARDED_SERVER"]}_#{meta["HTTP_X_FORWARDED_FOR"]}_#{meta["HTTP_X_FORWARDED_HOST"]}_#{meta["REMOTE_ADDR"]}_#{meta["HTTP_USER_AGENT"]}")
			@session_id = calc_id
			session = @kas.session_fromid(:idhash => @session_id, :ip => @ip)
			
			res.cookies << CGI::Cookie.new(
				"name" => "KnjappserverSession",
				"value" => @session_id,
				"path" => "/",
				"expires" => (Knj::Datet.new.months + 12).time
			).to_s
		end
		
		@session = session[:dbobj]
		@session_hash = session[:hash]
		@session_accessor = @session.accessor
		
		@kas.logs_access_pending << {
			:session_id => @session.id,
			:date_request => Knj::Datet.new.dbstr,
			:ips => @ips,
			:get => get,
			:post => post,
			:meta => meta,
			:cookie => cookie
		}
		
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
		
		serv_data[:headers].each do |header|
			key = header[0]
			val = header[1]
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
		
		res.status = serv_data[:statuscode] if serv_data[:statuscode]
		res.send_response(@socket)
		res.destroy
		
		#Letting them be nil is simply not enough (read that on a forum) - knj.
		serv_data.clear
	end
	
	def convert_webrick_post(seton, webrick_post, args = {})
		webrick_post.each do |varname, value|
			Knj::Web.parse_name(seton, varname, value, args)
		end
	end
	
	def serve_real(details)
		request = details[:request]
		headers = {}
		cont = ""
		statuscode = nil
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
		
		cache_use = false if cache_control["max-age"].to_i <= 0
		
		#check if we should use a handler for this request.
		handler_use = false
		@kas.config[:handlers].each do |handler_info|
			if handler_info[:file_ext] and handler_info[:file_ext] == details[:ext]
				handler_use = true
				ret = handler_info[:callback].call(details)
				cont = ret[:content] if ret[:content]
				headers = ret[:headers] if ret[:headers]
				break
			end
		end
		
		if !handler_use
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
					cont = File.read(details[:filepath]) #get plain content from file.
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