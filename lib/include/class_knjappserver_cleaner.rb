class Knjappserver
	def initialize_cleaner
		self.timeout(:time => 10) do
      if @should_restart
        #Lets try to find a time where no thread is working within the next 30 seconds. If we cant - we interrupt after 10 seconds and restart the server.
        begin
          Timeout.timeout(30) do
            loop do
              working_count = self.httpserv.working_count
              working = false
              
              if working_count > 0
                working = true
                STDOUT.print "Someone is working - wait two sec and try to restart again!\n"
              end
              
              if !working
                STDOUT.print "Found window where no sessions were active - restarting!\n"
                break
              else
                sleep 0.2
              end
            end
          end
        rescue Timeout::Error
          STDOUT.print "Could not find a timing window for restarting... Forcing restart!\n"
          #ignore - we will interrupt the working sessions.
        end
        
        self.stop
        self.mail_flush
        
        fpath = Knj::Php.realpath(File.dirname(__FILE__) + "/../knjappserver.rb")
        mycmd = Knj::Os.executed_cmd
        
        STDOUT.print "Previous cmd: #{mycmd}\n"
        mycmd = mycmd.gsub(/\s+knjappserver.rb/, " #{Knj::Strings.unixsafe(fpath)}")
        
        STDOUT.print "Restarting knjAppServer with command: #{mycmd}\n"
        exec(mycmd)
      end
    end
    
    self.timeout(:time => 300) do
      STDOUT.print "Cleaning sessions on appserver.\n" if @config[:debug]
      
      self.paused_exec do
        time_check = Time.now.to_i - 300
        @sessions.each do |ip, ip_sessions|
          ip_sessions.each do |session_hash, session_data|
            if session_data[:time_lastused].to_i <= time_check
              session_data[:dbobj].flush
              @ob.unset(session_data[:dbobj])
              session_data[:hash].clear
              ip_sessions.delete(session_hash)
              session_data.clear
            end
          end
          
          @sessions.delete(ip) if ip_sessions.empty?
        end
      end
    end
	end
end