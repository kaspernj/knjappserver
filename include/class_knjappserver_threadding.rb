class Knjappserver
	def thread(args = {})
		raise "No block given." if !block_given?
		args[:args] = [] if !args[:args]
		
		@threadpool.run_async(self) do |kas|
			Thread.current[:knjappserver] = {:kas => kas}
			
			begin
				kas.ob.db.get_and_register_thread
				kas.db_handler.get_and_register_thread
				yield(*args[:args])
			rescue Exception => e
				kas.handle_error(e)
			ensure
				kas.ob.db.free_thread
				kas.db_handler.free_thread
				Thread.current[:knjappserver] = nil
			end
		end
		
		return thread
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
						kas.ob.db.get_and_register_thread
						kas.db_handler.get_and_register_thread
						
						begin
							yield(*args[:args])
						ensure
							kas.ob.db.free_thread
							kas.db_handler.free_thread
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