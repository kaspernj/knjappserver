#coding: utf-8

def _(str)
	kas = _kas
	session = _session
	
	return str.to_s.encode("utf-8") if !kas or !session
	session[:locale] = kas.config[:locale_default] if !session[:locale] and kas.config[:locale_default]
	raise "No locale set for session and ':locale_default' not set in config." if !session[:locale]
	str = kas.gettext.trans(session[:locale], str)
	return str.to_s.encode("utf-8")
end