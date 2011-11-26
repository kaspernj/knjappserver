class Knjappserver::CustomIO < StringIO
	def print(str)
		thread = Thread.current
		str = str.to_s
		appsrv = thread[:knjappserver]
		
    if thread and appsrv and appsrv[:contentgroup] and appsrv[:httpsession]
      httpsession = appsrv[:httpsession]
      
      if httpsession
        wsize = httpsession.written_size
        wsize += str.size
        
        if wsize >= httpsession.size_send
          httpsession.cgroup.write_output
        end
      end
      
      appsrv[:contentgroup].write(str)
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