require "#{File.dirname(__FILE__)}/class_knjappserver_cleaner"
require "#{File.dirname(__FILE__)}/class_knjappserver_errors"
require "#{File.dirname(__FILE__)}/class_knjappserver_logging"
require "#{File.dirname(__FILE__)}/class_knjappserver_mailing"
require "#{File.dirname(__FILE__)}/class_knjappserver_sessions"
require "#{File.dirname(__FILE__)}/class_knjappserver_threadding"
require "#{File.dirname(__FILE__)}/class_knjappserver_translations"
require "#{File.dirname(__FILE__)}/class_knjappserver_web"

require "timeout"
require "digest"
require "erubis"
require "base64"
require "stringio"
require "socket"

class Knjappserver
  attr_reader :config, :httpserv, :debug, :db, :db_handler, :ob, :translations, :paused, :should_restart, :events, :mod_event, :db_handler, :gettext, :sessions, :logs_access_pending, :threadpool, :vars, :magic_vars, :types, :eruby_cache
  attr_accessor :served, :should_restart, :should_restart_done
  
  autoload :ERBHandler, "#{File.dirname(__FILE__)}/class_erbhandler"
  
  def initialize(config)
    raise "No arguments given." if !config.is_a?(Hash)
    
    @config = {
      :host => "0.0.0.0",
      :timeout => 30,
      :default_page => "index.rhtml",
      :default_filetype => "text/html",
      :max_requests_working => 20
    }.merge(config)
    
    @config[:smtp_args] = {"smtp_host" => "localhost", "smtp_port" => 25} if !@config[:smtp_args]
    @config[:timeout] = 30 if !@config.has_key?(:timeout)
    @config[:engine_knjengine] = true if !@config[:engine_knjengine] and !@config[:engine_webrick] and !@config[:engine_mongrel]
    raise "No ':doc_root' was given in arguments." if !@config.has_key?(:doc_root)
    
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
    
    @debug = @config[:debug]
    @paused = 0
    @paused_mutex = Mutex.new
    @should_restart = false
    @mod_events = {}
    @served = 0
    @mod_files = {}
    @sessions = {}
    @eruby_cache = {}
    
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
      "#{@path_knjappserver}/class_session.rb",
      "#{@path_knjappserver}/class_log.rb",
      "#{@path_knjappserver}/class_log_access.rb",
      "#{@path_knjappserver}/class_log_data_value.rb"
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
    
    
    print "Starting objects.\n" if @debug
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
      require "#{@path_knjappserver}/class_customio.rb"
      cio = Knjappserver::CustomIO.new
      $stdout = cio
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
    
    
    #Set up the 'vars'-variable that can be used to set custom global variables for web-requests.
    @vars = Knj::Hash_methods.new
    @magic_vars = {}
    
    
    #Initialize the various feature-modules.
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
    
    
    #Start the appserver.
    print "Spawning appserver.\n" if @debug
    @httpserv = Knjappserver::Httpserver.new(self)
    
    
    #Clear memory at exit.
    at_exit do
      self.stop
    end
    
    
    print "Appserver spawned.\n" if @debug
  end
  
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
      stop
    end
  end
  
  def stop
    proc_stop = proc{
      STDOUT.print "Stopping appserver for real.\n" if @debug
      @httpserv.stop if @httpserv and @httpserv.respond_to?(:stop)
      
      STDOUT.print "Stopping threadpool.\n" if @debug
      @threadpool.stop if @threadpool
      
      STDOUT.print "Flush out loaded sessions.\n" if @debug
      if @sessions
        @sessions.each do |session_hash, session_data|
          session_data[:dbobj].flush
        end
      end
    }
    
    #If we cant get a paused-execution in 10 secs - we just force the stop.
    begin
      Timeout.timeout(10) do
        self.paused_exec do
          proc_stop.call
        end
      end
    rescue Timeout::Error
      STDOUT.print "Forcing stop-appserver - couldnt get timing window.\n" if @debug
      proc_stop.call
    end
  end
  
  # Stop running any more http requests - make them wait.
  def pause
    @paused += 1
  end
  
  def unpause
    @paused -= 1
  end
  
  def paused?
    return true if @paused > 0
    return false
  end
  
  def paused_exec
    self.pause
    
    begin
      sleep 0.2 while @httpserv.working_count > 0
      @paused_mutex.synchronize do
        yield
      end
    ensure
      self.unpause
    end
  end
  
  def working?
    return true if @httpserv and @httpserv.working_count > 0
    return false
  end
  
  def self.data
    raise "Could not register current thread." if !Thread.current[:knjappserver]
    return Thread.current[:knjappserver]
  end
  
  def update_db
    require "rubygems" if !@config.key?(:knjdbrevision_path)
    require "#{@config[:knjdbrevision_path]}knjdbrevision"
    
    dbschemapath = "#{File.dirname(__FILE__)}/../files/database_schema.rb"
    raise "'#{dbschemapath}' did not exist." if !File.exists?(dbschemapath)
    require dbschemapath
    raise "No schema-variable was spawned." if !$tables
    
    dbpath = "#{File.dirname(__FILE__)}/../files/database.sqlite3"
    dbrev = Knjdbrevision.new
    dbrev.init_db($tables, @db)
  end
  
  def join
    raise "No http-server or http-server not running." if !@httpserv or !@httpserv.thread_accept
    
    begin
      @httpserv.thread_accept.join
      @httpserv.thread_restart.join
    rescue Interrupt
      stop
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
  
  def define_magic_var(method_name, var)
    @magic_vars[method_name] = var
    
    if !Object.respond_to?(method_name)
      Object.send(:define_method, method_name) do
        return Thread.current[:knjappserver][:kas].magic_vars[method_name] if Thread.current[:knjappserver] and Thread.current[:knjappserver][:kas]
        return $knjappserver[:knjappserver].magic_vars[method_name] if $knjappserver and $knjappserver[:knjappserver]
        raise "Could not figure out the object: '#{method_name}'."
      end
    end
  end
end