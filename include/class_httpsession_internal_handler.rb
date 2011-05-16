class Something
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
			cont = File.read(page_path)
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
		pinfo = Knj::Php.pathinfo(page_path)
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
end