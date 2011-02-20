def _cookie
	return Thread.current[:knjappserver][:cookie]
end

def _get
	return Thread.current[:knjappserver][:get]
end

def _post
	return Thread.current[:knjappserver][:post]
end

def _session
	return Thread.current[:knjappserver][:session_accessor]
end

def _session_hash
	return Thread.current[:knjappserver][:session_hash]
end

def _server
	return Thread.current[:knjappserver][:meta]
end

def _httpsession
	return Thread.current[:knjappserver][:httpsession]
end

def _requestdata
	return Thread.current[:knjappserver]
end

def _meta
	return Thread.current[:knjappserver][:meta]
end

def _kas
	return Thread.current[:knjappserver][:kas] if Thread.current[:knjappserver]
end

def _db
	return Thread.current[:knjappserver][:db] if Thread.current[:knjappserver]
	return $db #return the global database object, if we are not running in a thread with one.
end