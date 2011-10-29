require "digest"

class Knjappserver::Httpsession
  attr_accessor :data
  attr_reader :session, :session_id, :session_hash, :kas, :active, :out, :eruby, :browser, :debug, :resp
  
  def initialize(httpserver, socket)
    @data = {}
    @socket = socket
    @httpserver = httpserver
    @kas = httpserver.kas
    @active = true
    @eruby = Knj::Eruby.new(:cache_hash => @kas.eruby_cache)
    @debug = @kas.config[:debug]
    self.reset
    
    require "#{File.dirname(__FILE__)}/class_httpsession_knjengine"
    @handler = Knjappserver::Httpsession::Knjengine.new(:kas => @kas)
    
    Dir.chdir(@kas.config[:doc_root])
    ObjectSpace.define_finalizer(self, self.class.method(:finalize).to_proc) if @debug
    STDOUT.print "New httpsession #{self.__id__} (total: #{@httpserver.http_sessions.count}).\n" if @debug
    
    @thread_request = Knj::Thread.new do
      @kas.db_handler.get_and_register_thread if @kas.db_handler.opts[:threadsafe]
      @kas.ob.db.get_and_register_thread if @kas.ob.db.opts[:threadsafe]
      
      begin
        while @active
          begin
            Timeout.timeout(30) do
              @handler.socket_parse(@socket)
            end
            
            while @kas.paused? #Check if we should be waiting with executing the pending request.
              STDOUT.print "Paused! (#{@kas.paused}) - sleeping.\n" if @debug
              sleep 0.1
            end
            
            if @kas.config[:max_requests_working]
              while @httpserver.working_count >= @kas.config[:max_requests_working]
                STDOUT.print "Maximum amounts of requests are working (#{@httpserver.working_count}, #{@kas.config[:max_requests_working]}) - sleeping.\n" if @debug
                sleep 0.1
              end
            end
            
            @httpserver.handle_request do
              self.serve
            end
          ensure
            @kas.served += 1 if @kas
            self.reset
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
        @kas.db_handler.free_thread if @kas and @kas.db_handler.opts[:threadsafe]
        @kas.ob.db.free_thread if @kas and @kas.ob.db.opts[:threadsafe]
        self.destruct
      end
    end
  end
  
  def threadded_content(block)
    raise "No block was given." if !block
    @out = StringIO.new
    
    thread_out = StringIO.new
    thread = Thread.new(Thread.current[:knjappserver].clone) do |data|
      Thread.current[:knjappserver] = data
      Thread.current[:knjappserver][:stringio] = thread_out
      Thread.current[:knjappserver][:db] = @kas.db_handler
      
      @kas.db_handler.get_and_register_thread  if @kas.db_handler.opts[:threadsafe]
      @kas.ob.db.get_and_register_thread if @kas.ob.db.opts[:threadsafe]
      
      begin
        block.call
      rescue => e
        thread_out.print Knj::Errors.error_str(e, {:html => true})
        _kas.handle_error(e)
      ensure
        @kas.ob.db.free_thread if @kas.ob.db.opts[:threadsafe]
        @kas.db_handler.free_thread if @kas.db_handler.opts[:threadsafe]
      end
    end
    
    @parts << {
      :thread => thread,
      :stringio => thread_out
    }
    @parts << @out
  end
  
  def reset
    @out.close if @out
    @out = StringIO.new
    @parts = [@out]
  end
  
  def self.finalize(id)
    STDOUT.print "Httpsession finalize #{id}.\n" if @debug
  end
  
  def destruct
    STDOUT.print "Httpsession destruct (#{@httpserver.http_sessions.length})\n" if @debug and @httpserver
    
    begin
      @socket.close if @socket and !@socket.closed?
    rescue => e
      STDOUT.puts e.inspect
      STDOUT.puts e.backtrace
      #ignore if it fails...
    end
    
    @httpserver.http_sessions.delete(self) if @httpserver
    @httpserver = nil
    
    @data = nil
    @kas = nil
    @active = nil
    @session = nil
    @session_id = nil
    @session_hash = nil
    @out = nil
    @socket = nil
    @browser = nil
    @resp = nil
    @handler = nil
    
    @eruby.destroy if @eruby
    @eruby = nil
    
    thread = @thread_request
    @thread_request = nil
    thread.kill if thread and thread.alive?
  end
  
  def serve
    @resp = Knjappserver::Httpresp.new
    @resp.http_version = @handler.http_version
    @resp.close = true if @handler.meta["HTTP_CONNECTION"] == "close"
    
    meta = @handler.meta
    cookie = @handler.cookie
    page_path = @handler.page_path
    ext = File.extname(page_path).downcase[1..-1].to_s
    
    ctype = @kas.types[ext.to_sym] if ext.length > 0 and @kas.types.has_key?(ext.to_sym)
    ctype = @kas.config[:default_filetype] if !ctype and @kas.config.has_key?(:default_filetype)
    @resp.header("Content-Type", ctype)
    
    @browser = Knj::Web.browser(meta)
    
    if meta["HTTP_X_FORWARDED_FOR"]
      @ip = meta["HTTP_X_FORWARDED_FOR"].split(",")[0].strip
    elsif meta["REMOTE_ADDR"]
      @ip = meta["REMOTE_ADDR"]
    else
      raise "Could not figure out the IP of the session."
    end
    
    @session_id = nil
    
    if @browser["browser"] == "bot"
      @session_id = "bot"
    elsif cookie["KnjappserverSession"].to_s.length > 0
      @session_id = cookie["KnjappserverSession"] 
    else
      @session_id = @kas.session_generate_id(:meta => meta)
      send_cookie = true
    end
    
    begin
      session = @kas.session_fromid(:idhash => @session_id, :ip => @ip, :meta => meta)
    rescue Knj::Errors::InvalidData => e
      #User should not have the session he asked for because of invalid user-agent or invalid IP.
      @session_id = @kas.session_generate_id(:meta => meta)
      session = @kas.session_fromid(:idhash => @session_id, :ip => @ip, :meta => meta)
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
    
    @session = session[:dbobj]
    @session_hash = session[:hash]
    
    if @kas.config[:logging] and @kas.config[:logging][:access_db]
      @ips = [meta["REMOTE_ADDR"]]
      @ips << meta["HTTP_X_FORWARDED_FOR"].split(",")[0].strip if meta["HTTP_X_FORWARDED_FOR"]
      @kas.logs_access_pending << {
        :session_id => @session.id,
        :date_request => Time.now,
        :ips => @ips,
        :get => @handler.get,
        :post => @handler.post,
        :meta => meta,
        :cookie => cookie
      }
    end
    
    time_start = Time.now.to_f if @debug
    serv_data = self.serve_real(
      :filepath => page_path,
      :get => @handler.get,
      :post => @handler.post,
      :cookie => cookie,
      :meta => meta,
      :headers => {},
      :ctype => ctype,
      :ext => ext,
      :session => @session,
      :session_id => @session_id,
      :session_hash => @session_hash,
      :httpsession => self,
      :db => @kas.db_handler,
      :kas => @kas
    )
    
    serv_data[:headers].each do |header|
      @resp.header(header[0], header[1])
    end
    
    serv_data[:cookies].each do |cookie|
      @resp.cookie(cookie)
    end
    
    body_parts = []
    @parts.each do |part|
      if part.is_a?(Hash) and part[:thread]
        part[:thread].join
        part[:stringio].rewind
        body_parts << part[:stringio]
      elsif part.is_a?(StringIO) or part.is_a?(File)
        part.rewind
        body_parts << part
      else
        raise "Unknown object: '#{part.class.name}'."
      end
    end
    @resp.body = body_parts
    
    if serv_data[:lastmod]
      @resp.header("Last-Modified", serv_data[:lastmod].time)
      @resp.header("Expires", Time.now + (3600 * 24))
    end
    
    if serv_data[:cache]
      @resp.status = 304
      @resp.header("Last-Modified", serv_data[:lastmod].time)
      @resp.header("Expires", Time.now + (3600 * 24))
    end
    
    @resp.status = serv_data[:statuscode] if serv_data[:statuscode]
    STDOUT.print "Served '#{meta["REQUEST_URI"]}' in #{Time.now.to_f - time_start} secs.\n" if @debug
    
    @resp.write(@socket) if meta["METHOD"] != "HEAD"
    @resp = nil
    
    #Letting them be nil is simply not enough (read that on a forum) - knj.
    serv_data.clear
  end
  
  def serve_real(details)
    request = details[:request]
    headers = {}
    cookies = []
    cont = ""
    statuscode = nil
    lastmod = false
    max_age = 365 * 24
    
    cache = false
    cache_control = {}
    cache_use = true
    
    if @handler.headers["cache-control"] and @handler.headers["cache-control"][0]
      @handler.headers["cache-control"][0].scan(/(.+)=(.+)/) do |match|
        cache_control[match[1]] = match[2]
      end
    end
    
    cache_use = false if cache_control["max-age"].to_i <= 0
    
    #check if we should use a handler for this request.
    handler_use = false
    @kas.config[:handlers].each do |handler_info|
      if handler_info[:file_ext] and handler_info[:file_ext] == details[:ext]
        handler_use = true
        ret = handler_info[:callback].call(details)
        cont = ret[:content] if ret.has_key?(:content)
        headers = ret[:headers] if ret.has_key?(:headers)
        cookies = ret[:cookies] if ret.has_key?(:cookies)
        break
      elsif handler_info[:path] and handler_info[:mount] and details[:meta]["SCRIPT_NAME"].slice(0, handler_info[:path].length) == handler_info[:path]
        details[:filepath] = "#{handler_info[:mount]}#{details[:meta]["SCRIPT_NAME"].slice(handler_info[:path].length, details[:meta]["SCRIPT_NAME"].length)}"
        break
      end
    end
    
    if !handler_use
      if !File.exists?(details[:filepath])
        statuscode = 404
        headers["Content-Type"] = "text/html"
        @parts << StringIO.new("File you are looking for was not found: '#{details[:meta]["REQUEST_URI"]}'.")
      else
        lastmod = Knj::Datet.new(File.new(details[:filepath]).mtime)
        
        if cache_use and @handler.headers["if-modified-since"] and @handler.headers["if-modified-since"][0]
          request_mod = Knj::Datet.parse(@handler.headers["if-modified-since"][0])
          if request_mod == lastmod
            cache = true
          end
        end
        
        if !cache
          @parts << File.new(details[:filepath]) #get plain content from file.
        end
      end
    end
    
    details.clear
    
    return {
      :statuscode => statuscode,
      :content => cont,
      :headers => headers,
      :cookies => cookies,
      :lastmod => lastmod,
      :cache => cache
    }
  end
end