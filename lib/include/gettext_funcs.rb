def _(str)
	kas = _kas
	return str if !kas or !_session
	_session[:locale] = _kas.config[:locale_default] if !_session[:locale] and _kas.config[:locale_default]
	raise "No locale set for session and ':locale_default' not set in config." if !_session[:locale]
	str = kas.gettext.trans(_session[:locale], str)
	str = str.force_encoding("UTF-8") if str.respond_to?(:force_encoding)
	return str
end