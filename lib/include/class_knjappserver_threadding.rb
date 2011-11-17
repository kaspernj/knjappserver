class Knjappserver
	def initialize_threadding
    @config[:threadding] = {} if !@config.has_key?(:threadding)
    @config[:threadding][:max_running] = 25 if !@config[:threadding].has_key?(:max_running)
    
		@threadpool = Knj::Threadpool.new(:threads => @config[:threadding][:max_running])
		@threadpool.events.connect(:on_error) do |event, error|
      STDOUT.print "Error!\n"
			self.handle_error(error)
		end
	end
	
	#Inits the thread so it has access to the appserver and various magic methods can be used.
	def thread_init(thread = nil)
    thread = Thread.current if thread == nil
    thread[:knjappserver] = {} if !thread[:knjappserver]
    thread[:knjappserver][:kas] = self
	end
	
	#Spawns a new thread with access to magic methods, _db-method and various other stuff in the appserver.
	def thread(args = {})
		raise "No block given." if !block_given?
		args[:args] = [] if !args[:args]
		
		@threadpool.run_async do
      @ob.db.get_and_register_thread if @ob.db.opts[:threadsafe]
      @db_handler.get_and_register_thread if @db_handler.opts[:threadsafe]
      
      Thread.current[:knjappserver] = {
        :kas => self,
        :db => @db_handler
      }
      
			begin
				yield(*args[:args])
			rescue Exception => e
				handle_error(e)
			ensure
				@ob.db.free_thread if @ob.db.opts[:threadsafe]
				@db_handler.free_thread if @db_handler.opts[:threadsafe]
			end
		end
	end
	
	#Runs a proc every number of seconds.
	def timeout(args = {}, &block)
    to = Knjappserver::Threadding_timeout.new(
      :kas => self,
      :block => block,
      :args => args
    )
    to.start
    
    return to
	end
	
	#Spawns a thread to run the given proc and add the output of that block in the correct order to the HTML.
	def threadded_content(&block)
    _httpsession.threadded_content(block)
	end
end