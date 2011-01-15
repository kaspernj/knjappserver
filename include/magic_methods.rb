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
	return Thread.current[:knjappserver][:httpsession].session.accessor
end

def _session_hash
	return Thread.current[:knjappserver][:httpsession].session_hash
end

def _server
	return Thread.current[:knjappserver][:meta]
end

def _httpsession
	return Thread.current[:knjappserver][:httpsession]
end

def _meta
	return Thread.current[:knjappserver][:meta]
end

def _kas
	if Thread.current and Thread.current[:knjappserver] and Thread.current[:knjappserver][:httpsession]
		return Thread.current[:knjappserver][:httpsession].kas
	end
	
	return false
end

def _db
	return Thread.current[:knjappserver][:db] if Thread.current[:knjappserver]
	return $db #return the global database object, if we are not running in a thread with one.
end