require "time"

#This object writes headers, trailing headers, status headers and more for HTTP-sessions.
class Knjappserver::Httpresp
  attr_accessor :chunked, :cgroup, :nl, :status, :http_version, :headers, :headers_trailing, :headers_sent, :socket
  
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
    @chunked = false
    @socket = args[:socket]
  end
  
  def reset(args)
    @status = 200
    @http_version = args[:http_version]
    @close = args[:close]
    @fileobj = nil
    @close = true if @http_version == "1.0"
    @trailers = []
    
    @headers_sent = false
    @headers_trailing = {}
    
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
    if !@headers_sent
      @headers[key.to_s.downcase] = [key, val]
    else
      raise "Headers already sent and given header was not in trailing headers: '#{key}'." if @trailers.index(key) == nil
      @headers_trailing[key.to_s.downcase] = [key, val]
    end
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
      
      @trailers.each do |trailer|
        res += "Trailer: #{trailer}#{NL}"
      end
    end
    
    @cookies.each do |cookie|
      res += "Set-Cookie: #{Knj::Web.cookie_str(cookie)}#{NL}"
    end
    
    res += NL
    
    return res
  end
  
  def write
    @headers_sent = true
    @socket.write(self.header_str)
    
    if @status == 304
      #do nothing.
    else
      if @chunked
        @cgroup.write_to_socket
        @socket.write("0#{NL}")
        
        @headers_trailing.each do |header_id_str, header|
          @socket.write("#{header[0]}: #{header[1]}#{NL}")
        end
        
        @socket.write(NL)
      else
        @cgroup.write_to_socket
        @socket.write("#{NL}#{NL}")
      end
    end
    
    @socket.close if @close
  end
end