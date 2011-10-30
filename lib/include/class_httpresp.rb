require "time"

class Knjappserver::Httpresp
  attr_accessor :nl, :status, :http_version
  
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
  
  def initialize(args)
    @cgroup = args[:cgroup]
  end
  
  def reset(args)
    @status = 200
    @http_version = args[:http_version]
    @close = args[:close]
    @fileobj = nil
    @close = true if @http_version == "1.0"
    
    @headers = {
      "date" => ["Date", Time.now.httpdate]
    }
    
    @headers_11 = {
      "Connection" => "Keep-Alive",
      "Transfer-Encoding" => "chunked",
      "Keep-Alive" => "timeout=15, max=30"
    }
    
    @cookies = []
  end
  
  def header(key, val)
    @headers[key.to_s.downcase] = [key, val]
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
    
    @headers.each do |key, val|
      res += "#{val[0]}: #{val[1]}#{NL}"
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
    socket.write(self.header_str)
    
    if @status == 304
    
    else
      case @http_version
        when "1.0"
          @cgroup.write_to_socket
          socket.write("#{NL}#{NL}")
        when "1.1"
          @cgroup.write_to_socket
          socket.write("0#{NL}#{NL}")
        else
          raise "Could not figure out of HTTP version: '#{@http_version}'."
      end
    end
    
    socket.close if @close
  end
end