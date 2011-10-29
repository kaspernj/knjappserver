class Knjappserver
  attr_reader :error_emails_pending
  
	def initialize_errors
		@error_emails_pending = {}
		@error_emails_pending_mutex = Mutex.new
		
		if @config[:error_emails_time]
      @error_emails_time = @config[:error_emails_time]
    elsif @config[:debug]
      @error_emails_time = 5
    else
      @error_emails_time = 180
    end
		
		self.timeout(:time => @error_emails_time) do
			self.flush_error_emails
		end
	end
	
	#Send error-emails based on error-emails-cache (cached so the same error isnt send out every time it occurrs to prevent spamming).
	def flush_error_emails
		@error_emails_pending_mutex.synchronize do
			send_time_older_than = Time.new.to_i - @error_emails_time
			
			@error_emails_pending.each do |backtrace_hash, error_email|
				if send_time_older_than < error_email[:last_time].to_i and error_email[:messages].length < 1000
					next
				end
				
				@config[:error_report_emails].each do |email|
          next if !email
          
					if error_email[:messages].length == 1
						html = error_email[:messages].first
					else
						html = "<b>First time:</b> #{Knj::Datet.in(error_email[:first_time]).out}<br />"
						html += "<b>Last time:</b> #{Knj::Datet.in(error_email[:last_time]).out}<br />"
						html += "<b>Number of errors:</b> #{error_email[:messages].length}<br />"
						count = 0
						
						error_email[:messages].each do |error_msg|
							count += 1
							
							if count > 10
								html += "<br /><br /><b><i>Limiting to showing 10 out of #{error_email[:messages].length} messages.</i></b>"
								break
							end
							
							html += "<br /><br />"
							html += "<b>Message #{count}</b><br />"
							html += error_msg
						end
					end
					
					self.mail(
						:to => email,
						:subject => error_email[:subject],
						:html => html,
						:from => @config[:error_report_from]
					)
				end
				
				@error_emails_pending.delete(backtrace_hash)
			end
		end
	end
	
	#Handels a given error. Sends to the admin-emails.
	def handle_error(e, args = {})
		@error_emails_pending_mutex.synchronize do
			if !Thread.current[:knjappserver] or !Thread.current[:knjappserver][:httpsession]
				STDOUT.print "Error: "
				STDOUT.puts e.inspect
				STDOUT.print "\n"
				STDOUT.puts e.backtrace
				STDOUT.print "\n\n"
			end
			
			if @config.has_key?(:smtp_args) and @config[:error_report_emails] and (!args.has_key?(:email) or args[:email])
				backtrace_hash = Knj::ArrayExt.array_hash(e.backtrace)
				
				if !@error_emails_pending.has_key?(backtrace_hash)
					@error_emails_pending[backtrace_hash] = {
						:first_time => Time.new,
						:messages => [],
						:subject => sprintf("Error @ %s", @config[:title]) + " (#{Knj::Strings.shorten(e.message, 100)})"
					}
				end
				
				html = "An error occurred.<br /><br />"
				html += "<b>#{e.class.name.html}: #{e.message.html}</b><br /><br />"
				
				e.backtrace.each do |line|
					html += line.html + "<br />"
				end
				
				html += "<br /><b>Post:</b><br /><pre>#{Knj::Php.print_r(_post, true)}</pre>" if _post
				html += "<br /><b>Get:</b><br /><pre>#{Knj::Php.print_r(_get, true)}</pre>" if _get
				html += "<br /><b>Server:</b><br /><pre>#{Knj::Php.print_r(_server, true).html}</pre>" if _server
				html += "<br /><b>Cookie:</b><br /><pre>#{Knj::Php.print_r(_cookie, true).html}</pre>" if _meta
				html += "<br /><b>Session:</b><br /><pre>#{Knj::Php.print_r(_session, true).html}</pre>" if _session
				html += "<br /><b>Session hash:</b><br /><pre>#{Knj::Php.print_r(_session_hash, true).html}</pre>" if _session_hash
				
				error_hash = @error_emails_pending[backtrace_hash]
				error_hash[:last_time] = Time.new
				error_hash[:messages] << html
			end
		end
	end
	
	#Takes a proc and executes it. On error it alerts the error-message with javascript to the server, sends a javascript back and exits.
	def on_error_go_back(&block)
    begin
      block.call
    rescue => e
      self.alert(e.message).back
    end
	end
end