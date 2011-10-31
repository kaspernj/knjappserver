class Knjappserver::CustomIO < StringIO
	def print(str)
		thread = Thread.current
		
    if thread and thread[:knjappserver] and thread[:knjappserver][:contentgroup_str]
      thread[:knjappserver][:contentgroup_str] += str
		else
			STDOUT.print(str) if !STDOUT.closed?
		end
	end
	
	def <<(str)
		self.print(str)
	end
	
	def write(str)
		self.print(str)
	end
	
	def p(str)
    self.print(str)
	end
end