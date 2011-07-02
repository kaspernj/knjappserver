class Knjappserver::CustomIO < StringIO
	def print(str)
		thread = Thread.current
		
		if thread and thread[:knjappserver] and thread[:knjappserver][:httpsession] and thread[:knjappserver][:httpsession].out
			return thread[:knjappserver][:httpsession].out.print(str)
		else
			return STDOUT.print(str)
		end
	end
	
	def <<(str)
		self.print(str)
	end
	
	def write(str)
		self.print(str)
	end
end