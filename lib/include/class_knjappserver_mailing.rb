class Knjappserver
	def initialize_mailing
		@mails_waiting = []
		@mails_mutex = Mutex.new
		@mails_queue_mutex = Mutex.new
		@mails_timeout = self.timeout(:time => 10) do
			self.mail_flush
		end
	end
	
	def mail(mail_args)
		@mails_queue_mutex.synchronize do
			count_wait = 0
			while @mails_waiting.length > 100
				if count_wait >= 30
					raise "Could not send email - too many emails was pending and none of them were being sent?"
				end
				
				count_wait += 1
				sleep 1
			end
			
			mailobj = Knjappserver::Mail.new({:kas => self, :errors => {}, :status => :waiting}.merge(mail_args))
			@mails_waiting << mailobj
			return mailobj
		end
	end
	
	def mail_flush
		@mails_mutex.synchronize do
			return false if @mails_waiting.length <= 0
			
			status = Ping.pingecho("google.dk", 10, 80)
			if !status
				STDOUT.print "We are not online - skipping mail flush.\n"
				return false  #Dont run if we dont have a connection to the internet and then properly dont have a connection to the SMTP as well.
			end
			
			@mails_waiting.each do |mail|
				begin
					if mail.send
						@mails_waiting.delete(mail)
					end
				rescue Timeout::Error
					#ignore - 
				rescue => e
					@mails_waiting.delete(mail)
					self.handle_error(e, {:email => false})
				end
				
				sleep 1 #sleep so we dont take up too much bandwidth.
			end
		end
	end
	
	class Mail
		def initialize(args)
			@args = args
			
			raise "No knjappserver-object was given (as :kas)." if !@args[:kas].is_a?(Knjappserver)
			raise "No :to was given." if !@args[:to]
			raise "No content was given (:html)." if !@args[:html]
		end
		
		def [](key)
			return @args[key]
		end
		
		def send
			mail = Knj::Mailobj.new(@args[:kas].config[:smtp_args])
			mail.to = @args[:to]
			mail.subject = @args[:subject] if @args[:subject]
			mail.html = @args[:html] if @args[:html]
			
			if @args[:from]
				mail.from = @args[:from]
			else
				mail.from = @args[:kas].config[:error_report_from]
			end
			
			begin
				mail.send
				@args[:status] = :sent
				return true
			rescue SocketError => e
				@args[:errors][e.class.name] = {:count => 0} if !@args[:errors].has_key?(e.class.name)
				@args[:errors][e.class.name][:count] += 1
				raise e if @args[:errors][e.class.name][:count] >= 5
				@args[:status] = :error
				@args[:error] = e
				return false
			end
		end
	end
end