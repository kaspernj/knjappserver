require "time"

class Knjappserver::Httpresp
  attr_accessor :body, :nl, :status
  
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
      "Date" => Time.now.httpdate,
      "Connection" => "Keep-Alive",
      "Transfer-Encoding" => "chunked",
      "Keep-Alive" => "timeout=30, max=100"
    }
    @cookies = []
  end
  
  def header(key, val)
    @headers[key] = val
  end
  
  def cookie(cookie)
    @cookies << cookie
  end
  
  def header_str
    res = "HTTP/1.1 #{@status}"
    code = STATUS_CODES[@status]
    res += " #{code}" if code
    res += NL
    #res += "Content-Length: #{@body.length}#{NL}"
    
    @headers.each do |key, val|
      res += "#{key}: #{val}#{NL}"
    end
    
    @cookies.each do |cookie|
      res += "Set-Cookie: #{cookie}#{NL}"
    end
    
    res += NL
    
    return res
  end
  
  def write_chunked(socket)
    socket.write(self.header_str)
    
    while buf = @body.read(1024)
      next if buf.empty?
      socket.write("#{format("%x", buf.bytesize)}#{NL}#{buf}#{NL}")
    end
    
    socket.write("0#{NL}#{NL}")
  end
  
  def content
    str = self.header_str + @body.string + "\n\n"
  end
  
  def destroy
    @status = nil
    @status_codes = nil
    @body = nil
    @cookies = nil
    @headers = nil
  end
end