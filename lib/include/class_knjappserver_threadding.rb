class Knjappserver
  def initialize_threadding
    @config[:threadding] = {} if !@config.has_key?(:threadding)
    @config[:threadding][:max_running] = 8 if !@config[:threadding].has_key?(:max_running)
    
    @threadpool = Knj::Threadpool.new(:threads => @config[:threadding][:max_running], :sleep => 0.1)
    @threadpool.events.connect(:on_error) do |event, error|
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
    
    thread_obj = Knjappserver::Thread_instance.new(
      :running => false,
      :error => false,
      :done => false
    )
    
    @threadpool.run_async do
      @ob.db.get_and_register_thread if @ob.db.opts[:threadsafe]
      @db_handler.get_and_register_thread if @db_handler.opts[:threadsafe]
      
      Thread.current[:knjappserver] = {
        :kas => self,
        :db => @db_handler
      }
      
      begin
        thread_obj.args[:running] = true
        yield(*args[:args])
      rescue Exception => e
        handle_error(e)
        thread_obj.args[:error] = true
        thread_obj.args[:error_obj] = e
      ensure
        @ob.db.free_thread if @ob.db.opts[:threadsafe]
        @db_handler.free_thread if @db_handler.opts[:threadsafe]
        thread_obj.args[:running] = false
        thread_obj.args[:done] = true
      end
    end
    
    return thread_obj
  end
  
  #Runs a proc every number of seconds.
  def timeout(args = {}, &block)
    return Knjappserver::Threadding_timeout.new({
      :kas => self,
      :block => block,
      :args => []
    }.merge(args)).start
  end
  
  #Spawns a thread to run the given proc and add the output of that block in the correct order to the HTML.
  def threadded_content(&block)
    _httpsession.threadded_content(block)
  end
end

class Knjappserver::Thread_instance
  attr_reader :args
  
  def initialize(args)
    @args = args
  end
  
  def join
    sleep 0.1 while !@args[:done]
  end
  
  def join_error
    self.join
    raise @args[:error_obj] if @args[:error_obj]
  end
end