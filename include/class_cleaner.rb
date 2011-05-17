class Knjappserver::Cleaner
	def initialize(kas)
		@kas = kas
		
		Knj::Thread.new do
			loop do
				if @kas.should_restart
					dostop = true
					sess_arr = @kas.httpserv.http_sessions
					sess_arr.each do |sess|
						if sess.working
							print "Someone is working - wait two sec and try to restart again!\n"
							dostop = false
							break
						end
					end
					
					if dostop
						@kas.stop
						
						fpath = Knj::Php.realpath(File.dirname(__FILE__) + "/../knjappserver.rb")
						mycmd = Knj::Os.executed_cmd
						
						STDOUT.print "Previous cmd: #{mycmd}\n"
						mycmd = mycmd.gsub(/\s+knjappserver.rb/, " #{Knj::Strings.unixsafe(fpath)}")
						
						STDOUT.print "Restarting knjAppServer with command: #{mycmd}\n"
						exec(mycmd)
					end
				end
				
				sleep 2
			end
		end
	end
end