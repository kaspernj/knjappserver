def _cookie
	return Thread.current[:knjappserver][:cookie] if Thread.current[:knjappserver]
end

def _get
	return Thread.current[:knjappserver][:get] if Thread.current[:knjappserver]
end

def _post
	return Thread.current[:knjappserver][:post] if Thread.current[:knjappserver]
end

def _session
	return Thread.current[:knjappserver][:session].sess_data if Thread.current[:knjappserver] and Thread.current[:knjappserver][:session]
end

def _session_hash
	return Thread.current[:knjappserver][:session_hash] if Thread.current[:knjappserver]
end

def _session_obj
	return Thread.current[:knjappserver][:session] if Thread.current[:knjappserver]
end

def _server
	return Thread.current[:knjappserver][:meta] if Thread.current[:knjappserver]
end

def _httpsession
	return Thread.current[:knjappserver][:httpsession] if Thread.current[:knjappserver]
end

def _requestdata
	return Thread.current[:knjappserver] if Thread.current[:knjappserver]
end

def _meta
	return Thread.current[:knjappserver][:meta] if Thread.current[:knjappserver]
end

def _kas
	return Thread.current[:knjappserver][:kas] if Thread.current[:knjappserver]
	return $knjappserver[:knjappserver] if $knjappserver and $knjappserver[:knjappserver]
end

def _vars
  return Thread.current[:knjappserver][:kas].vars if Thread.current[:knjappserver]
  return $knjappserver[:knjappserver].vars if $knjappserver and $knjappserver[:knjappserver]
end

def _db
	return Thread.current[:knjappserver][:db] if Thread.current[:knjappserver]
	return $db if $db #return the global database object, if we are not running in a thread with one.
end