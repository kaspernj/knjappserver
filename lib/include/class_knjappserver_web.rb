class Knjappserver
	def redirect(url, args = {})
		return Knj::Web.redirect(url, args)
	end
	
	def alert(msg)
		Knj::Web.alert(msg)
		return self
	end
	
	def header(key, val)
    Knj::Php.header("#{key}: #{val}")
	end
	
	def header_raw(str)
    Knj::Php.header(str)
	end
	
	def back
		Knj::Web.back
		return self
	end
end