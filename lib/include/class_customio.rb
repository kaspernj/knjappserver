class Knjappserver::CustomIO < StringIO
	def print(str)
		thread = Thread.current
		str = str.to_s
		
    if thread and thread[:knjappserver] and thread[:knjappserver][:contentgroup]
      if thread[:knjappserver][:httpsession]
        wsize = thread[:knjappserver][:httpsession].written_size
        wsize += str.size
        
        if wsize > 1024
          thread[:knjappserver][:httpsession].cgroup.write_output
        end
      end
      
      thread[:knjappserver][:contentgroup].write(str)
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