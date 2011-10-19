class Knjappserver
  def import(filepath)
    _httpsession.eruby.import(filepath)
  end
  
	def redirect(url, args = {})
		return Knj::Web.redirect(url, args)
	end
	
	def alert(msg)
		Knj::Web.alert(msg)
		return self
	end
	
	def cookie(cookie)
    raise "No HTTP-session attached to this thread." if !_httpsession
    raise "HTTP-session not active." if !_httpsession.resp
    raise "Not a hash: '#{cookie.class.name}', '#{cookie}'." unless cookie.is_a?(Hash)
    _httpsession.resp.cookie(cookie)
	end
	
	def header(key, val)
    raise "No HTTP-session attached to this thread." if !_httpsession
    raise "HTTP-session not active." if !_httpsession.resp
    _httpsession.resp.header(key, val)
	end
	
	def header_raw(str)
    raise "No HTTP-session attached to this thread." if !_httpsession
    raise "HTTP-session not active." if !_httpsession.resp
    Knj::Php.header(str)
	end
	
	def back
		Knj::Web.back
	end
	
	def inputs(*args)
    return Knj::Web.inputs(args)
	end
end