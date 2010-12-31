def _cookie
	return Knjappserver.data[:cookie]
end

def _get
	return Knjappserver.data[:get]
end

def _post
	return Knjappserver.data[:post]
end

def _session
	return Knjappserver.data[:httpsession].session.accessor
end

def _session_hash
	return Knjappserver.data[:httpsession].session_hash
end

def _server
	return Knjappserver.data[:meta]
end

def _httpsession
	return Knjappserver.data[:httpsession]
end

def _meta
	return Knjappserver.data[:meta]
end

def _kas
	return Knjappserver.data[:httpsession].kas
end

def _db
	return Knjappserver.data[:db]
end