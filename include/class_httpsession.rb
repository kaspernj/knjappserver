class Knjappserver::Httpsession
	attr_accessor :data
	attr_reader :session, :session_id, :session_hash, :kas, :working, :active, :out, :eruby, :browser
	
	def initialize(httpserver, socket)
		@data = {}
		@socket = socket
		@httpserver = httpserver
		@kas = httpserver.kas
		@db = @kas.db_handler
		@active = true
		@working = true
		@eruby = Knj::Eruby.new
		
		if @kas.config[:engine_webrick]
			require "#{File.dirname(__FILE__)}/class_httpsession_webrick"
			@handler = Knjappserver::Httpsession::Webrick.new(:kas => @kas)
		elsif @kas.config[:engine_mongrel]
			require "#{File.dirname(__FILE__)}/class_httpsession_mongrel"
			@handler = Knjappserver::Httpsession::Mongrel.new(:kas => @kas)
		elsif @kas.config[:engine_knjengine]
			require "#{File.dirname(__FILE__)}/class_httpsession_knjengine"
			@handler = Knjappserver::Httpsession::Knjengine.new(:kas => @kas)
		else
			raise "Unknown handler."
		end
		
		ObjectSpace.define_finalizer(self, self.class.method(:finalize).to_proc) if @kas.config[:debug]
		STDOUT.print "New httpsession #{self.__id__} (total: #{@httpserver.http_sessions.count}).\n" if @kas.config[:debug]
		
		Knj::Thread.new do
			begin
				while @active
					begin
						@out = StringIO.new
						@handler.socket_parse(@socket)
						sleep 0.1 while @kas.paused? #Check if we should be waiting with executing the pending request.
						
						if @kas.config[:max_requests_working]
							while @httpserver.count_working > @kas.config[:max_requests_working]
								#STDOUT.print "Maximum amounts of requests are working - sleeping.\n"
								sleep 0.1
							end
						end
						
						Dir.chdir(@kas.config[:doc_root])
						@working = true
						@kas.db_handler.get_and_register_thread
						@kas.ob.db.get_and_register_thread
						self.serve
					ensure
						@kas.db_handler.free_thread
						@kas.ob.db.free_thread
						@kas.served += 1
						@working = false
					end
				end
				
				break
			rescue WEBrick::HTTPStatus::RequestTimeout, WEBrick::HTTPStatus::EOFError, Errno::ECONNRESET
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
		@browser = nil
		
		@eruby.destroy if @eruby
		@eruby = nil
		
		@handler.destroy if @handler
		@handler = nil
	end
	
	def close
		begin
			@socket.close if @socket
		rescue => e
			#ignore if it fails...
		end
	end
	
	def serve
		res = WEBrick::HTTPResponse.new({
			:HTTPVersion => WEBrick::HTTPVersion.new("1.1")
		})
		res.status = 200
		
		meta = @handler.meta
		cookie = @handler.cookie
		page_path = @handler.page_path
		
		pinfo = Knj::Php.pathinfo(page_path)
		ext = pinfo["extension"].downcase
		
		ctype = @kas.config[:default_filetype]
		ctype = @kas.config[:filetypes][ext.to_sym] if @kas.config[:filetypes][ext.to_sym]
		
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
		
		if @kas.config[:logging] and @kas.config[:logging][:access_db]
			@kas.logs_access_pending << {
				:session_id => @session.id,
				:date_request => Knj::Datet.new.dbstr,
				:ips => @ips,
				:get => @handler.get,
				:post => @handler.post,
				:meta => meta,
				:cookie => cookie
			}
		end
		
		serv_data = self.serve_real(
			:filepath => page_path,
			:get => @handler.get,
			:post => @handler.post,
			:cookie => cookie,
			:meta => meta,
			:headers => {},
			:ctype => ctype,
			:ext => ext,
			:session => @session,
			:session_id => @session_id,
			:session_accessor => @session_accessor,
			:session_hash => @session_hash,
			:httpsession => self,
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
		res.destroy if res.respond_to?(:destroy)
		
		#Letting them be nil is simply not enough (read that on a forum) - knj.
		serv_data.clear
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
		
		if @handler.headers["cache-control"] and @handler.headers["cache-control"][0]
			@handler.headers["cache-control"][0].scan(/(.+)=(.+)/) do |match|
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
				
				if cache_use and @handler.headers["if-modified-since"] and @handler.headers["if-modified-since"][0]
					request_mod = Knj::Datet.parse(@handler.headers["if-modified-since"][0])
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