require "time"

class Knjappserver::Httpresp
  attr_accessor :body, :nl, :status, :http_version, :close
  
  STATUS_CODES = {
    100 => "Continue",
    200 => "OK",
    201 => "Created",
    202 => "Accepted",
    204 => "No Content",
    205 => "Reset Content",
    206 => "Partial Content",
    301 => "Moved Permanently",
    302 => "Found",
    303 => "See Other",
    304 => "Not Modified",
    307 => "Temporary Redirect",
    400 => "Bad Request",
    401 => "Unauthorized",
    403 => "Forbidden",
    404 => "Not Found",
    500 => "Internal Server Error"
  }
  NL = "\r\n"
  
  def initialize
    @status = 200
    
    @headers = {
      "Content-Type" => "text/html",
      "Date" => Time.now.httpdate
    }
    
    @headers_11 = {
      "Connection" => "Keep-Alive",
      "Transfer-Encoding" => "chunked",
      "Keep-Alive" => "timeout=15, max=30"
    }
    
    @cookies = []
  end
  
  def content_length
    length = 0
    @body.each do |part|
      length += part.size
    end
    
    return length
  end
  
  def header(key, val)
    @headers[key] = val
  end
  
  def cookie(cookie)
    @cookies << cookie
  end
  
  def header_str
    if @http_version == "1.0"
      res = "HTTP/1.0 #{@status}"
    else
      res = "HTTP/1.1 #{@status}"
    end
    
    code = STATUS_CODES[@status]
    res += " #{code}" if code
    res += NL
    
    #res += "Content-Length: #{self.content_length}#{NL}"
    
    @headers.each do |key, val|
      res += "#{key}: #{val}#{NL}"
    end
    
    if @http_version == "1.1"
      @headers_11.each do |key, val|
        res += "#{key}: #{val}#{NL}"
      end
    end
    
    @cookies.each do |cookie|
      res += "Set-Cookie: #{Knj::Web.cookie_str(cookie)}#{NL}"
    end
    
    res += NL
    
    return res
  end
  
  def write(socket)
    case @http_version
      when "1.0"
        self.write_clean(socket)
        socket.close
      when "1.1"
        self.write_chunked(socket)
        socket.close if @close
      else
        raise "Could not figure out of HTTP version: '#{@http_version}'."
    end
  end
  
  def write_clean(socket)
    socket.write(self.header_str)
    
    @body.each do |part|
      while buf = part.read(512)
        next if buf.empty?
        socket.write(buf.to_s)
      end
    end
    
    socket.write("#{NL}#{NL}")
  end
  
  def write_chunked(socket)
    socket.write(self.header_str)
    
    @body.each do |part|
      while buf = part.read(512)
        next if buf.empty?
        socket.write("#{format("%x", buf.bytesize)}#{NL}#{buf}#{NL}")
      end
    end
    
    socket.write("0#{NL}#{NL}")
  end
  
  def content
    str = self.header_str + @body.string + "\n\n"
  end
end