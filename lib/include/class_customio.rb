class Knjappserver::CustomIO < StringIO
	def print(str)
		thread = Thread.current
		
    if thread and thread[:knjappserver] and thread[:knjappserver][:stringio] and !thread[:knjappserver][:stringio].closed?
      return thread[:knjappserver][:stringio].print(str)
		elsif thread and thread[:knjappserver] and thread[:knjappserver][:httpsession] and thread[:knjappserver][:httpsession].out and !thread[:knjappserver][:httpsession].out.closed?
			return thread[:knjappserver][:httpsession].out.print(str)
		else
			return STDOUT.print(str) if !STDOUT.closed?
		end
	end
	
	def <<(str)
		self.print(str)
	end
	
	def write(str)
		self.print(str)
	end
end