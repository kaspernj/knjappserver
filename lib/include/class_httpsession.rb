class Knjappserver::Httpsession
  attr_accessor :data, :size_send, :alert_sent
  attr_reader :session, :session_id, :session_hash, :kas, :active, :out, :eruby, :browser, :debug, :resp, :page_path, :cgroup, :written_size, :meta, :httpsession_var, :handler, :working
  
  dir = File.dirname(__FILE__)
  
  autoload :Contentgroup, "#{dir}/class_httpsession_contentgroup.rb"
  autoload :Http_request, "#{dir}/class_httpsession_http_request.rb"
  autoload :Http_response, "#{dir}/class_httpsession_http_response.rb"
  autoload :Post_multipart, "#{dir}/class_httpsession_post_multipart.rb"
  
  def initialize(httpserver, socket)
    @data = {}
    @socket = socket
    @httpserver = httpserver
    @kas = httpserver.kas
    @types = @kas.types
    @config = @kas.config
    @active = true
    @eruby = Knj::Eruby.new(:cache_hash => @kas.eruby_cache)
    @debug = @kas.debug
    @handlers_cache = @config[:handlers_cache]
    @httpsession_var = {}
    
    #Set socket stuff.
    if RUBY_PLATFORM == "java" or RUBY_ENGINE == "rbx"
      if @kas.config[:peeraddr_static]
        addr_peer = [0, 0, @kas.config[:peeraddr_static]]
      else
        addr_peer = @socket.peeraddr
      end
      
      addr = @socket.addr
    else
      addr = @socket.addr(false)
      addr_peer = @socket.peeraddr(false)
    end
    
    @socket_meta = {
      "REMOTE_ADDR" => addr[2],
      "REMOTE_PORT" => addr[1],
      "SERVER_ADDR" => addr_peer[2],
      "SERVER_PORT" => addr_peer[1]
    }
    
    @resp = Knjappserver::Httpsession::Http_response.new(:socket => @socket)
    @handler = Knjappserver::Httpsession::Http_request.new(:kas => @kas, :httpsession => self)
    
    @cgroup = Knjappserver::Httpsession::Contentgroup.new(
      :socket => @socket,
      :kas => @kas,
      :resp => @resp,
      :httpsession => self
    )
    @resp.cgroup = @cgroup
    
    Dir.chdir(@config[:doc_root])
    ObjectSpace.define_finalizer(self, self.class.method(:finalize).to_proc) if @debug
    STDOUT.print "New httpsession #{self.__id__} (total: #{@httpserver.http_sessions.count}).\n" if @debug
    
    @thread_request = Knj::Thread.new do
      Thread.current[:knjappserver] = {} if !Thread.current[:knjappserver]
      
      begin
        while @active
          begin
            @cgroup.reset
            @written_size = 0
            @size_send = @config[:size_send]
            @alert_sent = false
            @working = false
            
            Timeout.timeout(1500) do
              @handler.socket_parse(@socket)
            end
            
            while @kas.paused? #Check if we should be waiting with executing the pending request.
              STDOUT.print "Paused! (#{@kas.paused}) - sleeping.\n" if @debug
              sleep 0.1
            end
            
            break if @kas.should_restart
            
            if @config.key?(:max_requests_working)
              while @httpserver and @config and @httpserver.working_count >= @config[:max_requests_working]
                STDOUT.print "Maximum amounts of requests are working (#{@httpserver.working_count}, #{@config[:max_requests_working]}) - sleeping.\n" if @debug
                sleep 0.1
              end
            end
            
            #Reserve database connections.
            @kas.db_handler.get_and_register_thread if @kas.db_handler.opts[:threadsafe]
            @kas.ob.db.get_and_register_thread if @kas.ob.db.opts[:threadsafe]
            
            @httpserver.count_add
            @working = true
            self.serve
          ensure
            @httpserver.count_remove
            @kas.served += 1 if @kas
            @working = false
            
            #Free reserved database-connections.
            @kas.db_handler.free_thread if @kas and @kas.db_handler.opts[:threadsafe]
            @kas.ob.db.free_thread if @kas and @kas.ob.db.opts[:threadsafe]
          end
        end
      rescue Errno::ECONNRESET, Errno::ENOTCONN, Errno::EPIPE, Timeout::Error => e
        #Ignore - the user probaly left.
        #STDOUT.puts e.inspect
        #STDOUT.puts e.backtrace
      rescue SystemExit, Interrupt => e
        raise e
      rescue RuntimeError, Exception => e
        STDOUT.puts e.inspect
        STDOUT.puts e.backtrace
      ensure
        self.destruct
      end
    end
  end
  
  def threadded_content(block)
    raise "No block was given." if !block
    cgroup = Thread.current[:knjappserver][:contentgroup].new_thread
    
    Thread.new do
      begin
        self.init_thread
        cgroup.register_thread
        
        @kas.db_handler.get_and_register_thread if @kas and @kas.db_handler.opts[:threadsafe]
        @kas.ob.db.get_and_register_thread if @kas and @kas.ob.db.opts[:threadsafe]
        
        block.call
      rescue Exception => e
        Thread.current[:knjappserver][:contentgroup].write Knj::Errors.error_str(e, {:html => true})
        _kas.handle_error(e)
      ensure
        Thread.current[:knjappserver][:contentgroup].mark_done
        @kas.ob.db.free_thread if @kas and @kas.ob.db.opts[:threadsafe]
        @kas.db_handler.free_thread if @kas and @kas.db_handler.opts[:threadsafe]
      end
    end
  end
  
  def init_thread
    Thread.current[:knjappserver] = {} if !Thread.current[:knjappserver]
    Thread.current[:knjappserver][:kas] = @kas
    Thread.current[:knjappserver][:httpsession] = self
    Thread.current[:knjappserver][:session] = @session
    Thread.current[:knjappserver][:get] = @get
    Thread.current[:knjappserver][:post] = @post
    Thread.current[:knjappserver][:meta] = @meta
    Thread.current[:knjappserver][:cookie] = @cookie
  end
  
  def self.finalize(id)
    STDOUT.print "Httpsession finalize #{id}.\n" if @debug
  end
  
  def destruct
    STDOUT.print "Httpsession destruct (#{@httpserver.http_sessions.length})\n" if @debug and @httpserver and @httpserver.http_sessions
    
    begin
      @socket.close if !@socket.closed?
    rescue => e
      STDOUT.puts e.inspect
      STDOUT.puts e.backtrace
      #ignore if it fails...
    end
    
    @httpserver.http_sessions.delete(self) if @httpserver and @httpserver.http_sessions
    
    @eruby.destroy if @eruby
    @thread_request.kill if @thread_request.alive?
  end
  
  #Forces the content to be the input - nothing else can be added after calling this.
  def force_content(newcont)
    @cgroup.force_content(newcont)
  end
  
  def serve
    @meta = @handler.meta.merge!(@socket_meta)
    @cookie = @handler.cookie
    @get = @handler.get
    @post = @handler.post
    @headers = @handler.headers
    
    close = true if @meta["HTTP_CONNECTION"] == "close"
    @resp.reset(
      :http_version => @handler.http_version,
      :close => close 
    )
    if @handler.http_version == "1.1"
      @cgroup.chunked = true
      @resp.chunked = true
    else
      @cgroup.chunked = false
      @resp.chunked = false
    end
    
    @page_path = @handler.page_path
    @ext = File.extname(@page_path).downcase[1..-1].to_s
    
    @ctype = @types[@ext.to_sym] if @ext.length > 0 and @types.key?(@ext.to_sym)
    @ctype = @config[:default_filetype] if !@ctype and @config.key?(:default_filetype)
    @resp.header("Content-Type", @ctype)
    
    @browser = Knj::Web.browser(@meta)
    
    if @meta["HTTP_X_FORWARDED_FOR"]
      @ip = @meta["HTTP_X_FORWARDED_FOR"].split(",")[0].strip
    elsif @meta["REMOTE_ADDR"]
      @ip = @meta["REMOTE_ADDR"]
    else
      raise "Could not figure out the IP of the session."
    end
    
    if @cookie["KnjappserverSession"].to_s.length > 0
      @session_id = @cookie["KnjappserverSession"]
    elsif @browser["browser"] == "bot"
      @session_id = "bot"
    else
      @session_id = @kas.session_generate_id(@meta)
      send_cookie = true
    end
    
    begin
      @session, @session_hash = @kas.session_fromid(@ip, @session_id, @meta)
    rescue Knj::Errors::InvalidData => e
      #User should not have the session he asked for because of invalid user-agent or invalid IP.
      @session_id = @kas.session_generate_id(@meta)
      @session, @session_hash = @kas.session_fromid(@ip, @session_id, @meta)
      send_cookie = true
    end
    
    if send_cookie
      @resp.cookie(
        "name" => "KnjappserverSession",
        "value" => @session_id,
        "path" => "/",
        "expires" => Time.now + 32140800 #add around 12 months
      )
    end
    
    if @config.key?(:logging) and @config[:logging][:access_db]
      @ips = [@meta["REMOTE_ADDR"]]
      @ips << @meta["HTTP_X_FORWARDED_FOR"].split(",")[0].strip if @meta["HTTP_X_FORWARDED_FOR"]
      @kas.logs_access_pending << {
        :session_id => @session.id,
        :date_request => Time.now,
        :ips => @ips,
        :get => @get,
        :post => @post,
        :meta => @meta,
        :cookie => @cookie
      }
    end
    
    self.init_thread
    Thread.current[:knjappserver][:contentgroup] = @cgroup
    time_start = Time.now.to_f if @debug
    
    @kas.events.call(:request_begin, {
      :httpsession => self
    }) if @kas.events
    
    if @handlers_cache.key?(@ext)
      @handlers_cache[@ext].call(self)
    else
      #check if we should use a handler for this request.
      @config[:handlers].each do |handler_info|
        if handler_info.key?(:file_ext) and handler_info[:file_ext] == @ext
          return handler_info[:callback].call(self)
        elsif handler_info.key?(:path) and handler_info[:mount] and @meta["SCRIPT_NAME"].slice(0, handler_info[:path].length) == handler_info[:path]
          @page_path = "#{handler_info[:mount]}#{@meta["SCRIPT_NAME"].slice(handler_info[:path].length, @meta["SCRIPT_NAME"].length)}"
          break
        end
      end
      
      if !File.exists?(@page_path)
        @resp.status = 404
        @resp.header("Content-Type", "text/html")
        @cgroup.write("File you are looking for was not found: '#{@meta["REQUEST_URI"]}'.")
      else
        if @headers["cache-control"] and @headers["cache-control"][0]
          cache_control = {}
          @headers["cache-control"][0].scan(/(.+)=(.+)/) do |match|
            cache_control[match[1]] = match[2]
          end
        end
        
        cache_dont = true if cache_control and cache_control.key?("max-age") and cache_control["max-age"].to_i <= 0
        lastmod = File.mtime(@page_path)
        
        @resp.header("Last-Modified", lastmod.httpdate)
        @resp.header("Expires", (Time.now + 86400).httpdate) #next day.
        
        if !cache_dont and @headers["if-modified-since"] and @headers["if-modified-since"][0]
          request_mod = Knj::Datet.parse(@headers["if-modified-since"][0]).time
          
          if request_mod == lastmod
            @resp.status = 304
            return nil
          end
        end
        
        @cgroup.new_io(File.new(@page_path))
      end
    end
    
    @cgroup.mark_done
    @cgroup.write_output
    STDOUT.print "#{__id__} - Served '#{@meta["REQUEST_URI"]}' in #{Time.now.to_f - time_start} secs (#{@resp.status}).\n" if @debug
    @cgroup.join
    
    @kas.events.call(:request_done, {
      :httpsession => self
    }) if @kas.events
    @httpsession_var = {}
  end
end