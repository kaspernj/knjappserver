class Knjappserver
  #Imports a .rhtml-file and executes it.
  def import(filepath)
    _httpsession.eruby.import(filepath)
  end
  
  #Redirects to another URL.
	def redirect(url, args = {})
		return Knj::Web.redirect(url, args)
	end
	
	#Sends a javascript-alert to the HTML.
	def alert(msg)
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
end