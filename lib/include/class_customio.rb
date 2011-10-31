class Knjappserver::CustomIO < StringIO
	def print(str)
		thread = Thread.current
		
    if thread and thread[:knjappserver] and thread[:knjappserver][:contentgroup] and !thread[:knjappserver][:contentgroup].done
      return thread[:knjappserver][:contentgroup].write(str)
		else
      if thread[:knjappserver] and thread[:knjappserver][:contentgroup]
        STDOUT.print "Str: '#{str}'\n"
        STDOUT.print "Done: #{thread[:knjappserver][:contentgroup].done}\n"
      end
      
      #STDOUT.print Knj::Php.print_r(Thread.current[:knjappserver], true)
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