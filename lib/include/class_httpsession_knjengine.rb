require "uri"

if RUBY_PLATFORM == "java" or RUBY_ENGINE == "rbx"
  BasicSocket.do_not_reverse_lookup = true
end

class Knjappserver::Httpsession::Knjengine
	attr_reader :get, :post, :cookie, :meta, :page_path, :headers, :http_version
	
	def initialize(args)
		@args = args
		@kas = @args[:kas]
		@crlf = "\r\n"
	end
	
	def read_socket
		loop do
			raise Errno::ECONNRESET, "Socket closed." if @socket.closed?
			read = @socket.gets
			raise Errno::ECONNRESET, "Socket returned non-string." if !read.is_a?(String)
			@cont += read
			break if @cont[-4..-1] == "\r\n\r\n" or @cont[-2..-1] == "\n\n"
		end
	end
	
	def socket_parse(socket)
		@cont = ""
		@socket = socket
		self.read_socket
		
		#Parse URI (page_path and get).
		match = @cont.match(/^(GET|POST|HEAD) (.+) HTTP\/1\.(\d+)\s*/)
		raise "Could not parse request: '#{@cont.split("\n").first}'." if !match
    
		@http_version = "1.#{match[3]}"
		
		method = match[1]
		@cont = @cont.gsub(match[0], "")
		uri = URI.parse(match[2])
		
		page_filepath = Knj::Web.urldec(uri.path)
		if page_filepath.length <= 0 or page_filepath == "/" or File.directory?("#{@kas.config[:doc_root]}/#{page_filepath}")
			page_filepath = "#{page_filepath}/#{@kas.config[:default_page]}"
		end
		
		@page_path = "#{@kas.config[:doc_root]}/#{page_filepath}"
		@get = Knj::Web.parse_urlquery(uri.query.to_s, {:urldecode => true, :force_utf8 => true})
		
		
		#Parse headers, cookies and meta.
		if RUBY_PLATFORM == "java" or RUBY_ENGINE == "rbx"
			if @kas.config[:peeraddr_static]
				addr_peer = [0, 0, @kas.config[:peeraddr_static]]
			else
				addr_peer = @socket.peeraddr
			end
			
			addr = @socket.addr
		else
			addr = @socket.addr(false)
			addr_peer = @socket.peeraddr(false)
		end
		
		@headers = {}
		@cookie = {}
		@meta = {
			"REQUEST_METHOD" => method,
			"QUERY_STRING" => uri.query,
			"REQUEST_URI" => match[2],
			"REMOTE_ADDR" => addr[2],
			"REMOTE_PORT" => addr[1],
			"SERVER_ADDR" => addr_peer[2],
			"SERVER_PORT" => addr_peer[1],
			"SCRIPT_NAME" => uri.path
		}
		
		@cont.scan(/(\S+):\s*(.+)\r\n/) do |header_match|
			key = header_match[0].downcase
			val = header_match[1]
			
			@headers[key] = [] if !@headers.has_key?(key)
			@headers[key] << val
			
			case key
				when "host"
					@meta["HTTP_HOST"] = val
				when "connection"
					@meta["HTTP_CONNECTION"] = val
				when "accept"
					@meta["HTTP_ACCEPT"] = val
				when "accept-encoding"
					@meta["HTTP_ACCEPT_ENCODING"] = val
				when "accept-language"
					@meta["HTTP_ACCEPT_LANGUAGE"] = val
				when "accept-charset"
					@meta["HTTP_ACCEPT_CHARSET"] = val
				when "user-agent"
					@meta["HTTP_USER_AGENT"] = val
				when "referer"
					@meta["HTTP_REFERER"] = val
				when "cookie"
					Knj::Web.parse_cookies(val).each do |key, val|
						@cookie[key] = val
					end
			end
		end
		
		
		#Parse post
		@post = {}
		
		if method == "POST"
			post_treated = {}
			post_data = @socket.read(@headers["content-length"][0].to_i)
			
			if @headers["content-type"] and match = @headers["content-type"][0].match(/^multipart\/form-data; boundary=(.+)\Z/)
				io = StringIO.new(post_data)
				post_treated = parse_form_data(io, match[1])
			else
				post_data.split("&").each do |splitted|
					splitted = splitted.split("=")
					post_treated[Knj::Php.urldecode(splitted[0])] = splitted[1]
				end
			end
			
			self.convert_webrick_post(@post, post_treated, {:urldecode => true, :force_utf8 => true})
		end
	end
	
	def convert_webrick_post(seton, webrick_post, args = {})
		webrick_post.each do |varname, value|
			Knj::Web.parse_name(seton, varname, value, args)
		end
	end
	
	#Thanks to WEBrick
	def parse_form_data(io, boundary)
		boundary_regexp = /\A--#{boundary}(--)?#{@crlf}\z/
		form_data = Hash.new
		return form_data unless io
		data = nil
		io.each{|line|
		  if boundary_regexp =~ line
			 if data
				data.chop!
				key = data.name
				if form_data.has_key?(key)
				  form_data[key].append_data(data)
				else
				  form_data[key] = data 
				end
			 end
			 data = WEBrick::HTTPUtils::FormData.new
			 next
		  else
			 if data
				data << line
			 end
		  end
		}
		return form_data
  end
end