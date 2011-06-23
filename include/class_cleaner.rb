class Knjappserver::Cleaner
	def initialize(kas)
		@kas = kas
		
		Knj::Thread.new do
			loop do
				if !@kas.should_restart
					sleep 2
					next
				end
				
				#Lets try to find a time where no thread is working within the next 30 seconds. If we cant - we interrupt after 10 seconds and restart the server.
				begin
					Timeout.timeout(30) do
						loop do
							sess_arr = @kas.httpserv.http_sessions
							working = false
							
							sess_arr.each do |sess|
								if sess.working
									STDOUT.print "Someone is working - wait two sec and try to restart again!\n"
									working = true
									break
								end
							end
							
							if !working
								STDOUT.print "Found window where no sessions were active - restarting!\n"
								break
							else
								sleep 0.1
							end
						end
					end
				rescue Timeout::Error
					STDOUT.print "Could not find a timing window for restarting... Forcing restart!\n"
					#ignore - we will interrupt the working sessions.
				end
				
				@kas.stop
				
				fpath = Knj::Php.realpath(File.dirname(__FILE__) + "/../knjappserver.rb")
				mycmd = Knj::Os.executed_cmd
				
				STDOUT.print "Previous cmd: #{mycmd}\n"
				mycmd = mycmd.gsub(/\s+knjappserver.rb/, " #{Knj::Strings.unixsafe(fpath)}")
				
				STDOUT.print "Restarting knjAppServer with command: #{mycmd}\n"
				exec(mycmd)
			end
		end
	end
end