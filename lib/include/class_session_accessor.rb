class Knjappserver::Session_accessor
	attr_reader :session
	
	def initialize(session)
		@session = session
	end
	
	def [](key)
		return @session.sess_data[key]
	end
	
	def []=(key,val)
		sess_data = @session.sess_data
		ret = sess_data[key] = val
		@session.sess_data = sess_data
		return ret
	end
	
	def each(&args)
		return @session.sess_data.each(&args)
	end
	
	def delete(key)
		sess_data = @session.sess_data
		ret = sess_data.delete(key)
		@session.sess_data = sess_data
		return ret
	end
end