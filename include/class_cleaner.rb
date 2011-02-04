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
						print "Restarting knjAppServer...\n"
						exec("ruby \"#{fpath}\" >> /dev/null 2>&1 &")
					end
				end
				
				sleep 2
			end
		end
	end
end