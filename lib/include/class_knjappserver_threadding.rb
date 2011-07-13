class Knjappserver
	def initialize_threadding
    @config[:threadding] = {} if !@config.has_key?(:threadding)
    @config[:threadding][:max_running] = 25 if !@config[:threadding].has_key?(:max_running)
    
		@threadpool = Knj::Threadpool.new(:threads => @config[:threadding][:max_running])
		@threadpool.events.connect(:on_error) do |event, error|
			self.handle_error(error)
		end
	end
	
	def thread(args = {})
		raise "No block given." if !block_given?
		args[:args] = [] if !args[:args]
		
		@threadpool.run_async(self) do |kas|
			begin
        Thread.current[:knjappserver] = {:kas => kas}
				kas.ob.db.get_and_register_thread if kas.ob.db.opts[:threadsafe]
				kas.db_handler.get_and_register_thread if kas.db_handler.opts[:threadsafe]
				yield(*args[:args])
			rescue Exception => e
				kas.handle_error(e)
			ensure
				kas.ob.db.free_thread if kas.ob.db.opts[:threadsafe]
				kas.db_handler.free_thread if kas.db_handler.opts[:threadsafe]
				Thread.current[:knjappserver] = nil
			end
		end
	end
	
	def timeout(args = {})
		raise "No time given." if !args.has_key?(:time)
		raise "No block given." if !block_given?
		args[:args] = [] if !args[:args]
		
		thread = Thread.new(self) do |kas|
      Thread.current[:knjappserver] = {:kas => kas}
			loop do
				begin
					if args[:counting]
						Thread.current[:knjappserver_timeout] = args[:time].to_s.to_i
						
						while Thread.current[:knjappserver_timeout] > 0
							Thread.current[:knjappserver_timeout] += -1
							sleep 1
						end
					else
						sleep args[:time]
					end
					
					@threadpool.run do
            Thread.current[:knjappserver] = {:kas => kas}
						kas.ob.db.get_and_register_thread if kas.ob.db.opts[:threadsafe]
						kas.db_handler.get_and_register_thread if kas.db_handler.opts[:threadsafe]
						
						begin
							yield(*args[:args])
						ensure
              Thread.current[:knjappserver] = nil
							kas.ob.db.free_thread if kas.ob.db.opts[:threadsafe]
							kas.db_handler.free_thread if kas.db_handler.opts[:threadsafe]
						end
					end
				rescue Exception => e
					kas.handle_error(e)
				end
			end
		end
		
		return thread
	end
end