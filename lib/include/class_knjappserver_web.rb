class Knjappserver
  #Imports a .rhtml-file and executes it.
  def import(filepath)
    if filepath.to_s.index("../proc/self") != nil
      raise Knj::Errors::NoAccess, "Possible attempt to hack the appserver."
    end
    
    _httpsession.eruby.import(filepath)
  end
  
  #Redirects to another URL.
  def redirect(url, args = {})
    #Header way
    if !_httpsession.alert_sent and !self.headers_sent?
      if args[:perm]
        _httpsession.resp.status = 301 if !self.headers_sent?
      else
        _httpsession.resp.status = 303 if !self.headers_sent?
      end
      
      self.header("Location", url) if !self.headers_sent?
    end
    
    print "<script type=\"text/javascript\">location.href=\"#{url}\";</script>"
    exit
  end
  
  #Sends a javascript-alert to the HTML.
  def alert(msg)
    _httpsession.alert_sent = true
    Knj::Web.alert(msg)
    return self
  end
  
  #Define a cookies in the clients browser.
  def cookie(cookie)
    raise "No HTTP-session attached to this thread." if !_httpsession
    raise "HTTP-session not active." if !_httpsession.resp
    raise "Not a hash: '#{cookie.class.name}', '#{cookie}'." unless cookie.is_a?(Hash)
    _httpsession.resp.cookie(cookie)
  end
  
  #Sends a header to the clients browser.
  def header(key, val)
    raise "No HTTP-session attached to this thread." if !_httpsession
    raise "HTTP-session not active." if !_httpsession.resp
    _httpsession.resp.header(key, val)
  end
  
  #Sends a raw header-line to the clients browser.
  def header_raw(str)
    raise "No HTTP-session attached to this thread." if !_httpsession
    raise "HTTP-session not active." if !_httpsession.resp
    Knj::Php.header(str)
  end
  
  def headers_sent?
    return true if _httpsession.resp.headers_sent
    return false
  end
  
  def headers_send_size=(newsize)
    if self.headers_sent?
      raise "The headers are already sent and you cannot modify the send-size any more."
    end
    
    _httpsession.size_send = newsize.to_i
  end
  
  #Sends a javascript back to the browser and exits.
  def back
    Knj::Web.back
  end
  
  #Draw a input in a table.
  def inputs(*args)
    return Knj::Web.inputs(args)
  end
  
  #Urlencodes a string.
  def urlenc(str)
    return Knj::Web.urlenc(str)
  end
  
  #Urldecodes a string.
  def urldec(str)
    return Knj::Web.urldec(str)
  end
  
  #Returns a number localized as a string.
  def num(*args)
    return Knj::Locales.number_out(*args)
  end
  
  def get_parse_arrays(arg = nil, ob = nil)
    arg = _get.clone if !arg
    
    #Parses key-numeric-hashes into arrays and converts special model-strings into actual models.
    if arg.is_a?(Hash) and Knj::ArrayExt.hash_numeric_keys?(arg)
      arr = []
      
      arg.each do |key, val|
        arr << val
      end
      
      return self.get_parse_arrays(arr, ob)
    elsif arg.is_a?(Hash)
      arg.each do |key, val|
        arg[key] = self.get_parse_arrays(val, ob)
      end
      
      return arg
    elsif arg.is_a?(Array)
      arg.each_index do |key|
        arg[key] = self.get_parse_arrays(arg[key], ob)
      end
      
      return arg
    elsif arg.is_a?(String) and match = arg.match(/^#<Model::(.+?)::(\d+)>$/)
      ob = @ob if !ob
      return ob.get(match[1], match[2])
    else
      return arg
    end
  end
  
  #Returns the socket-port the appserver is currently running on.
  def port
    raise "Http-server not spawned yet. Call Knjappserver#start to spawn it." if !@httpserv
    return @httpserv.server.addr[1]
  end
end