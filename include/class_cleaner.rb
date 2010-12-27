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
							print "Someone is working - wait one sec and try to restart again!\n"
							dostop = false
							break
						end
					end
					
					if dostop
						@kas.stop
						fpath = Php.realpath(File.dirname(__FILE__) + "/../knjappserver.rb")
						print "Restarting knjAppServer...\n"
						exec "ruby \"#{fpath}\""
					end
				end
				
				sleep 1
			end
		end
	end
end