require "uri"

if RUBY_PLATFORM == "java" or RUBY_ENGINE == "rbx"
  BasicSocket.do_not_reverse_lookup = true
end

class Knjappserver::Httpsession::Knjengine
	attr_reader :get, :post, :cookie, :meta, :page_path, :headers, :http_version, :read, :clength, :speed, :percent, :secs_left
	
	def initialize(args)
		@args = args
		@kas = @args[:kas]
		@crlf = "\r\n"
	end
	
	def read_socket
		loop do
			raise Errno::ECONNRESET, "Socket closed." if @socket.closed?
			read = @socket.gets
			raise Errno::ECONNRESET, "Socket returned non-string: '#{read.class.name}'." if !read.is_a?(String)
			@cont << read
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
		
    if @get["_kas_httpsession_id"]
      @kas.httpsessions_ids[@get["_kas_httpsession_id"]] = @args[:httpsession]
		end
    
		begin
      #Parse headers, cookies and meta.
      @headers = {}
      @cookie = {}
      @meta = {
        "REQUEST_METHOD" => method,
        "QUERY_STRING" => uri.query,
        "REQUEST_URI" => match[2],
        "SCRIPT_NAME" => uri.path
      }
      
      @cont.scan(/^(\S+):\s*(.+)\r\n/) do |header_match|
        key = header_match[0].downcase
        val = header_match[1]
        
        @headers[key] = [] if !@headers.has_key?(key)
        @headers[key] << val
        
        case key
          when "cookie"
            Knj::Web.parse_cookies(val).each do |key, val|
              @cookie[key] = val
            end
          when "content-length"
            @clength = val.to_i
          else
            key = key.upcase.gsub("-", "_")
            @meta["HTTP_#{key}"] = val
        end
      end
      
      
      #Parse post
      @post = {}
      
      if method == "POST"
        post_treated = {}
        
        @speed = nil
        @read = 0
        post_data = ""
        
        Knj::Thread.new do
          time_cur = Time.now
          read_last = 0
          
          while @clength and @read != nil and @read < @clength
            sleep 2
            break if !@clength or !@read
            
            time_now = Time.now
            time_betw = time_now.to_f - time_cur.to_f
            read_betw = @read - read_last
            
            time_cur = time_now
            read_last = @read
            
            @percent = @read.to_f / @clength.to_f
            @speed = read_betw.to_f / time_betw.to_f
            
            bytes_left = @clength - read
            
            if @speed > 0 and bytes_left > 0
              @secs_left = bytes_left.to_f / @speed
            else
              @secs_left = false
            end
          end
        end
        
        while @read < @clength
          read_size = @clength - @read
          read_size = 4096 if read_size > 4096
          
          raise Errno::ECONNRESET, "Socket closed." if @socket.closed?
          read = @socket.read(read_size)
          raise Errno::ECONNRESET, "Socket returned non-string: '#{read.class.name}'." if !read.is_a?(String)
          post_data << read
          @read += read.length
        end
        
        if @headers["content-type"] and match = @headers["content-type"].first.match(/^multipart\/form-data; boundary=(.+)\Z/)
          io = StringIO.new(post_data)
          post_treated = parse_form_data(io, match[1])
        else
          post_data.split("&").each do |splitted|
            splitted = splitted.split("=")
            key = Knj::Web.urldec(splitted[0]).to_s.encode("utf-8")
            val = splitted[1].to_s.encode("utf-8")
            post_treated[key] = val
          end
        end
        
        self.convert_webrick_post(@post, post_treated, {:urldecode => true})
      end
		ensure
      @read = nil
      @speed = nil
      @clength = nil
      @percent = nil
      @secs_left = nil
      
      #If it doesnt get unset we could have a serious memory reference GC problem.
      if @get["_kas_httpsession_id"]
        @kas.httpsessions_ids.delete(@get["_kas_httpsession_id"])
      end
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
		form_data = {}
		return form_data unless io
		data = nil
		
		io.each do |line|
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
		end
		
		return form_data
  end
end