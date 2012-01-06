require "timeout"
require "digest"
require "erubis"
require "base64"
require "stringio"
require "socket"

class Knjappserver
  attr_reader :config, :httpserv, :debug, :db, :db_handler, :ob, :translations, :paused, :should_restart, :events, :mod_event, :db_handler, :gettext, :sessions, :logs_access_pending, :threadpool, :vars, :magic_procs, :magic_vars, :types, :eruby_cache, :httpsessions_ids
  attr_accessor :served, :should_restart, :should_restart_done
  
  autoload :ERBHandler, "#{File.dirname(__FILE__)}/class_erbhandler"
  
  def initialize(config)
    raise "No arguments given." if !config.is_a?(Hash)
    
    @config = {
      :host => "0.0.0.0",
      :timeout => 30,
      :default_page => "index.rhtml",
      :default_filetype => "text/html",
      :max_requests_working => 20,
      :size_send => 1024
    }.merge(config)
    
    @config[:smtp_args] = {"smtp_host" => "localhost", "smtp_port" => 25} if !@config[:smtp_args]
    @config[:timeout] = 30 if !@config.has_key?(:timeout)
    @config[:engine_knjengine] = true if !@config[:engine_knjengine] and !@config[:engine_webrick] and !@config[:engine_mongrel]
    raise "No ':doc_root' was given in arguments." if !@config.has_key?(:doc_root)
    
    
    #Setup default handlers if none are given.
    if !@config.has_key?(:handlers)
      @erbhandler = Knjappserver::ERBHandler.new
      @config[:handlers] = [
        {
          :file_ext => "rhtml",
          :callback => @erbhandler.method(:erb_handler)
        },{
          :path => "/fckeditor",
          :mount => "/usr/share/fckeditor"
        }
      ]
    end
    
    
    #Add extra handlers if given.
    if @config[:handlers_extra]
      @config[:handlers] += @config[:handlers_extra]
    end
    
    
    #Setup cache to make .rhtml-calls faster.
    @config[:handlers_cache] = {}
    @config[:handlers].each do |handler_info|
      next if !handler_info[:file_ext] or !handler_info[:callback]
      @config[:handlers_cache][handler_info[:file_ext]] = handler_info[:callback]
    end
    
    
    @debug = @config[:debug]
    @paused = 0
    @paused_mutex = Mutex.new
    @should_restart = false
    @mod_events = {}
    @served = 0
    @mod_files = {}
    @sessions = {}
    @eruby_cache = {}
    @httpsessions_ids = {}
    
    @path_knjappserver = File.dirname(__FILE__)
    if @config[:knjrbfw_path]
      @path_knjrbfw = @config[:knjrbfw_path]
    elsif $knjappserver_config and $knjappserver_config["knjrbfw"]
      @path_knjrbfw = $knjappserver_config["knjrbfw"]
    else
      @path_knjrbfw = ""
    end
    
    
    #If auto-restarting is enabled - start the modified events-module.
    if @config[:autorestart]
      paths = [
        "#{@path_knjappserver}/../knjappserver.rb",
        "#{@path_knjappserver}/class_knjappserver.rb",
        "#{@path_knjappserver}/class_customio.rb"
      ]
      
      print "Auto restarting.\n" if @debug
      @mod_event = Knj::Event_filemod.new(:wait => 2, :paths => paths) do |event, path|
        print "File changed - restart server: #{path}\n"
        @should_restart = true
        @mod_event.destroy if @mod_event
      end
    end
    
    
    #Set up default file-types and merge given filetypes into it.
    @types = {
      :ico => "image/x-icon",
      :jpeg => "image/jpeg",
      :jpg => "image/jpeg",
      :gif => "image/gif",
      :png => "image/png",
      :html => "text/html",
      :htm => "text/html",
      :rhtml => "text/html",
      :css => "text/css",
      :xml => "text/xml",
      :js => "text/javascript"
    }
    @types = @types.merge(@config[:filetypes]) if @config.has_key?(:filetypes)
    
    
    
    #Load various required files from knjrbfw and stuff in the knjappserver-framework.
    files = [
      "#{@path_knjrbfw}knjrbfw.rb",
      "#{@path_knjrbfw}knj/arrayext.rb",
      "#{@path_knjrbfw}knj/event_handler.rb",
      "#{@path_knjrbfw}knj/errors.rb",
      "#{@path_knjrbfw}knj/eruby.rb",
      "#{@path_knjrbfw}knj/hash_methods.rb",
      "#{@path_knjrbfw}knj/objects.rb",
      "#{@path_knjrbfw}knj/web.rb",
      "#{@path_knjrbfw}knj/datarow.rb",
      "#{@path_knjrbfw}knj/datet.rb",
      "#{@path_knjrbfw}knj/php.rb",
      "#{@path_knjrbfw}knj/thread.rb",
      "#{@path_knjrbfw}knj/threadhandler.rb",
      "#{@path_knjrbfw}knj/threadpool.rb",
      "#{@path_knjrbfw}knj/translations.rb",
      "#{@path_knjrbfw}knj/knjdb/libknjdb.rb",
      "#{@path_knjappserver}/class_httpresp.rb",
      "#{@path_knjappserver}/class_httpserver.rb",
      "#{@path_knjappserver}/class_httpsession.rb",
      "#{@path_knjappserver}/class_httpsession_knjengine.rb",
      "#{@path_knjappserver}/class_httpsession_contentgroup.rb",
      "#{@path_knjappserver}/class_session.rb",
      "#{@path_knjappserver}/class_log.rb",
      "#{@path_knjappserver}/class_log_access.rb",
      "#{@path_knjappserver}/class_log_data_value.rb",
      "#{@path_knjappserver}/class_knjappserver_cleaner.rb",
      "#{@path_knjappserver}/class_knjappserver_cmdline.rb",
      "#{@path_knjappserver}/class_knjappserver_errors.rb",
      "#{@path_knjappserver}/class_knjappserver_logging.rb",
      "#{@path_knjappserver}/class_knjappserver_mailing.rb",
      "#{@path_knjappserver}/class_knjappserver_sessions.rb",
      "#{@path_knjappserver}/class_knjappserver_threadding.rb",
      "#{@path_knjappserver}/class_knjappserver_threadding_timeout.rb",
      "#{@path_knjappserver}/class_knjappserver_translations.rb",
      "#{@path_knjappserver}/class_knjappserver_web.rb"
    ]
    files << "#{@path_knjrbfw}knj/gettext_threadded.rb" if @config[:locales_root]
    files.each do |file|
      STDOUT.print "Loading: '#{file}'.\n" if @debug
      self.loadfile(file)
    end
    
    
    print "Setting up database.\n" if @debug
    if @config[:db].is_a?(Knj::Db)
      @db = @config[:db]
    elsif @config[:db].is_a?(Hash)
      @db = Knj::Db.new(@config[:db])
    elsif !@config[:db] and @config[:db_args]
      @db = Knj::Db.new(@config[:db_args])
    else
      raise "Unknown object given as db: '#{@config[:db].class.name}'."
    end
    
    
    print "Updating database.\n" if @debug
    require "rubygems" if !@config.key?(:knjdbrevision_path)
    require "#{@config[:knjdbrevision_path]}knjdbrevision"
    
    dbschemapath = "#{File.dirname(__FILE__)}/../files/database_schema.rb"
    raise "'#{dbschemapath}' did not exist." if !File.exists?(dbschemapath)
    require dbschemapath
    raise "No schema-variable was spawned." if !DATABASE_SCHEMA
    
    dbpath = "#{File.dirname(__FILE__)}/../files/database.sqlite3"
    dbrev = Knjdbrevision.new
    dbrev.init_db(DATABASE_SCHEMA, @db)
    
    
    print "Spawning objects.\n" if @debug
    @ob = Knj::Objects.new(
      :db => db,
      :class_path => @path_knjappserver,
      :module => Knjappserver,
      :datarow => true,
      :knjappserver => self
    )
    @ob.events.connect(:no_date) do |event, classname|
      "[no date]"
    end
    
    
    if @config[:httpsession_db_args]
      @db_handler = Knj::Db.new(@config[:httpsession_db_args])
    else
      @db_handler = @db
    end
    
    
    #Start the Knj::Gettext_threadded- and Knj::Translations modules for translations.
    print "Loading Gettext and translations.\n" if @debug
    @translations = Knj::Translations.new(:db => @db)
    @ob.requireclass(:Translation, {:require => false, :class => Knj::Translations::Translation})
    
    if @config[:locales_root]
      @gettext = Knj::Gettext_threadded.new("dir" => config[:locales_root])
    end
    
    if @config[:locales_gettext_funcs]
      require "#{@path_knjappserver}/gettext_funcs"
    end
    
    if @config[:magic_methods] or !@config.has_key?(:magic_methods)
      print "Loading magic-methods.\n" if @debug
      require "#{@path_knjappserver}/magic_methods"
    end
    
    if @config[:customio] or !@config.has_key?(:customio)
      print "Loading custom-io.\n" if @debug
      
      if $stdout.class.name != "Knjappserver::CustomIO"
        require "#{@path_knjappserver}/class_customio.rb"
        cio = Knjappserver::CustomIO.new
        $stdout = cio
      end
    end
    
    
    #Save the PID to the run-file.
    print "Setting run-file.\n" if @debug
    require "tmpdir"
    tmpdir = "#{Dir.tmpdir}/knjappserver"
    tmppath = "#{tmpdir}/run_#{@config[:title]}"
    
    if !File.exists?(tmpdir)
      Dir.mkdir(tmpdir)
      File.chmod(0777, tmpdir)
    end
    
    File.open(tmppath, "w") do |fp|
      fp.write(Process.pid)
    end
    File.chmod(0777, tmppath)
    
    
    #Set up various events for the appserver.
    print "Loading events.\n" if @debug
    @events = Knj::Event_handler.new
    @events.add_event(
      :name => :check_page_access,
      :connections_max => 1
    )
    @events.add_event(
      :name => :ob,
      :connections_max => 1
    )
    @events.add_event(
      :name => :trans_no_str,
      :connections_max => 1
    )
    
    #Set up the 'vars'-variable that can be used to set custom global variables for web-requests.
    @vars = Knj::Hash_methods.new
    @magic_vars = {}
    @magic_procs = {}
    
    
    #Initialize the various feature-modules.
    print "Init sessions.\n" if @debug
    initialize_sessions
    
    print "Init threadding.\n" if @debug
    initialize_threadding
    
    print "Init mailing.\n" if @debug
    initialize_mailing
    
    print "Init errors.\n" if @debug
    initialize_errors
    
    print "Init logging.\n" if @debug
    initialize_logging
    
    print "Init cleaner.\n" if @debug
    initialize_cleaner
    
    print "Init cmdline.\n" if @debug
    initialize_cmdline
    
    
    #Start the appserver.
    print "Spawning appserver.\n" if @debug
    @httpserv = Knjappserver::Httpserver.new(self)
    
    
    #Clear memory at exit.
    at_exit do
      self.stop
    end
    
    
    print "Appserver spawned.\n" if @debug
  end
  
  #If you want to use auto-restart, every file reloaded through loadfile will be watched for changes. When changed the server will do a restart to reflect that.
  def loadfile(fpath)
    if !@config[:autorestart]
      require fpath
      return nil
    end
    
    rpath = Knj::Php.realpath(fpath)
    raise "No such filepath: #{fpath}" if !rpath or !File.exists?(rpath)
    
    return true if @mod_files[rpath]
    
    @mod_event.args[:paths] << rpath
    @mod_files = rpath
    
    require rpath
    return false
  end
  
  #Starts the HTTP-server and threadpool.
  def start
    STDOUT.print "Starting appserver.\n" if @debug
    Thread.current[:knjappserver] = {:kas => self} if !Thread.current[:knjappserver]
    
    if @config[:autoload]
      STDOUT.print "Autoloading #{@config[:autoload]}\n" if @debug
      require @config[:autoload]
    end
    
    begin
      @threadpool.start if @threadpool
      STDOUT.print "Threadpool startet.\n" if @debug
      @httpserv.start
      STDOUT.print "Appserver startet.\n" if @debug
    rescue Interrupt
      STDOUT.print "Got interrupt - stopping appserver.\n" if @debug
      self.stop
    end
  end
  
  #Stops the entire app and releases join.
  def stop
    proc_stop = proc{
      #This should be done first to be sure it finishes (else we have a serious bug).
      STDOUT.print "Flush out loaded sessions.\n" if @debug
      self.sessions_flush
      
      STDOUT.print "Stopping appserver for real.\n" if @debug
      @httpserv.stop if @httpserv and @httpserv.respond_to?(:stop)
      
      STDOUT.print "Stopping threadpool.\n" if @debug
      @threadpool.stop if @threadpool
    }
    
    #If we cant get a paused-execution in 10 secs - we just force the stop.
    begin
      Timeout.timeout(10) do
        self.paused_exec do
          proc_stop.call
        end
      end
    rescue Timeout::Error, SystemExit, Interrupt
      STDOUT.print "Forcing stop-appserver - couldnt get timing window.\n" if @debug
      proc_stop.call
    end
  end
  
  #Stop running any more HTTP-requests - make them wait.
  def pause
    @paused += 1
  end
  
  #Unpause - start handeling HTTP-requests again.
  def unpause
    @paused -= 1
  end
  
  #Returns true if paued - otherwise false.
  def paused?
    return true if @paused > 0
    return false
  end
  
  #Will stop handeling any more HTTP-requests, run the proc given and return handeling HTTP-requests.
  def paused_exec
    self.pause
    
    begin
      sleep 0.2 while @httpserv and @httpserv.working_count and @httpserv.working_count > 0
      @paused_mutex.synchronize do
        yield
      end
    ensure
      self.unpause
    end
  end
  
  #Returns true if a HTTP-request is working. Otherwise false.
  def working?
    return true if @httpserv and @httpserv.working_count > 0
    return false
  end
  
  def self.data
    raise "Could not register current thread." if !Thread.current[:knjappserver]
    return Thread.current[:knjappserver]
  end
  
  #Sleeps until the server is stopped.
  def join
    raise "No http-server or http-server not running." if !@httpserv or !@httpserv.thread_accept
    
    begin
      @httpserv.thread_accept.join
      @httpserv.thread_restart.join if @httpserv and @httpserv.thread_restart
    rescue Interrupt
      self.stop
    end
    
    if @should_restart
      loop do
        if @should_restart_done
          STDOUT.print "Ending join because the restart is done.\n"
          break
        end
        
        sleep 1
      end
    end
  end
  
  #Defines a variable as a method bound to the threads spawned by this instance of Knjappserver.
  def define_magic_var(method_name, var)
    @magic_vars[method_name] = var
    
    if !Object.respond_to?(method_name)
      Object.send(:define_method, method_name) do
        return Thread.current[:knjappserver][:kas].magic_vars[method_name] if Thread.current[:knjappserver] and Thread.current[:knjappserver][:kas]
        raise "Could not figure out the object: '#{method_name}'."
      end
    end
  end
  
  def define_magic_proc(method_name, &block)
    raise "No block given." if !block_given?
    @magic_procs[method_name] = block
    
    if !Object.respond_to?(method_name)
      Object.send(:define_method, method_name) do
        return Thread.current[:knjappserver][:kas].magic_procs[method_name].call(:kas => self) if Thread.current[:knjappserver] and Thread.current[:knjappserver][:kas]
        raise "Could not figure out the object: '#{method_name}'."
      end
    end
  end
end