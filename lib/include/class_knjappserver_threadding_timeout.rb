class Knjappserver::Threadding_timeout
  def initialize(args)
    @args = args
    @kas = @args[:kas]
    raise "No time given." if !@args[:args].key?(:time)
    @args[:time] = @args[:args][:time].to_s.to_i
    @args[:args] = [] if !@args[:args]
    @mutex = Mutex.new
  end
  
  def time=(newtime)
    @args[:time] = newtime.to_s.to_i
  end
  
  def time
    return @args[:time]
  end
  
  #Starts the timeout.
  def start
    @run = true
    @thread = Thread.new do
      loop do
        begin
          if @args[:counting]
            Thread.current[:knjappserver_timeout] = @args[:time]
            
            while Thread.current[:knjappserver_timeout] > 0
              Thread.current[:knjappserver_timeout] += -1
              break if @kas.should_restart or !@run
              sleep 1
            end
          else
            sleep @args[:time]
          end
          
          break if @kas.should_restart or !@run
          
          @mutex.synchronize do
            @kas.threadpool.run do
              @kas.ob.db.get_and_register_thread if @kas.ob.db.opts[:threadsafe]
              @kas.db_handler.get_and_register_thread if @kas.db_handler.opts[:threadsafe]
              
              Thread.current[:knjappserver] = {
                :kas => self,
                :db => @kas.db_handler
              }
              
              begin
                @args[:block].call(*@args[:args])
              ensure
                @kas.ob.db.free_thread if @kas.ob.db.opts[:threadsafe]
                @kas.db_handler.free_thread if @kas.db_handler.opts[:threadsafe]
              end
            end
          end
        rescue Exception => e
          @kas.handle_error(e)
        end
      end
    end
  end
  
  #Stops the timeout.
  def stop
    @run = false
    @mutex.synchronize do
      @thread.kill if @thread.alive?
      @thread = nil
    end
  end
end