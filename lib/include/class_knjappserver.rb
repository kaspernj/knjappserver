require "#{File.dirname(__FILE__)}/class_knjappserver_errors"
require "#{File.dirname(__FILE__)}/class_knjappserver_logging"
require "#{File.dirname(__FILE__)}/class_knjappserver_mailing"
require "#{File.dirname(__FILE__)}/class_knjappserver_threadding"
require "#{File.dirname(__FILE__)}/class_knjappserver_web"
require "#{File.dirname(__FILE__)}/class_knjappserver_cleaner"

class Knjappserver
  attr_reader :config, :httpserv, :db, :db_handler, :ob, :translations, :paused, :should_restart, :events, :mod_event, :paused, :db_handler, :gettext, :sessions, :logs_access_pending, :threadpool, :vars, :magic_vars, :types
  attr_accessor :served, :should_restart
  
  autoload :ERBHandler, "#{File.dirname(__FILE__)}/class_erbhandler"
  
  def initialize(config)
    @config = config
    @config[:timeout] = 30 if !@config.has_key?(:timeout)
    
    @paused = 0
    @should_restart = false
    @mod_events = {}
    @served = 0
    @mod_files = {}
    @sessions = {}
    
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
      
      print "Auto restarting.\n"
      @mod_event = Knj::Event_filemod.new(:wait => 2, :paths => paths) do |event, path|
        print "File changed - restart server: #{path}\n"
        @should_restart = true
        @mod_event.destroy
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
    @types = @types.merge(@config[:filetypes]) if @config[:filetypes]
    
    
    files = [
      "#{@path_knjappserver}/class_session_accessor.rb",
      "#{@path_knjappserver}/class_httpresp.rb",
      "#{@path_knjappserver}/class_httpserver.rb",
      "#{@path_knjappserver}/class_httpsession.rb",
      "#{@path_knjappserver}/class_session.rb",
      "#{@path_knjappserver}/class_session_accessor.rb",
      "#{@path_knjappserver}/class_log.rb",
      "#{@path_knjappserver}/class_log_access.rb",
      "#{@path_knjappserver}/class_log_data_value.rb",
      "#{@path_knjrbfw}knj/objects.rb",
      "#{@path_knjrbfw}knj/web.rb",
      "#{@path_knjrbfw}knj/datet.rb",
      "#{@path_knjrbfw}knj/thread.rb",
      "#{@path_knjrbfw}knj/threadhandler.rb",
      "#{@path_knjrbfw}knj/knjdb/libknjdb.rb"
    ]
    files.each do |file|
      STDOUT.print "Loading: '#{file}'.\n"
      
      if @config[:autorestart]
        self.loadfile(file)
      else
        require file
      end
    end
    
    
    @db = @config[:db]
    @ob = Knj::Objects.new(
      :db => db,
      :class_path => @path_knjappserver,
      :module => Knjappserver,
      :datarow => true,
      :knjappserver => self
    )
    
    
    if @config[:httpsession_db_args]
      @db_handler = Knj::Db.new(@config[:httpsession_db_args])
    else
      @db_handler = @db
    end
    
    
    #Start the Knj::Gettext_threadded- and Knj::Translations modules for translations.
    @translations = Knj::Translations.new(:db => @db)
    if @config[:locales_root]
      @gettext = Knj::Gettext_threadded.new("dir" => config[:locales_root])
    end
    
    if @config[:locales_gettext_funcs]
      require "#{@path_knjappserver}/gettext_funcs"
    end
    
    if @config[:magic_methods] or !@config.has_key?(:magic_methods)
      require "#{@path_knjappserver}/magic_methods"
    end
    
    if @config[:customio] or !@config.has_key?(:customio)
      require "#{@path_knjappserver}/class_customio.rb"
      cio = Knjappserver::CustomIO.new
      $stdout = cio
    end
    
    
    #Save the PID to the run-file.
    if RUBY_ENGINE != "rbx"
      require "tmpdir"
      tmpdir = "#{Dir.tmpdir}/knjappserver"
      tmppath = "#{tmpdir}/run_#{@config[:title]}"
      
      Dir.mkdir(tmpdir) if !File.exists?(tmpdir)
      File.open(tmppath, "w") do |fp|
        fp.write(Process.pid)
      end
    end
    
    
    #Set up various events for the appserver.
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
    initialize_threadding
    initialize_mailing
    initialize_errors
    initialize_logging
    initialize_cleaner
    
    
    #Start the appserver.
    @httpserv = Knjappserver::Httpserver.new(self)
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
    Thread.current[:knjappserver] = {:kas => self} if !Thread.current[:knjappserver]
    
    if @config[:autoload]
      print "Autoloading #{@config[:autoload]}\n"
      require @config[:autoload]
    end
    
    @httpserv.start
  end
  
  def stop
    @httpserv.stop
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
      loop do
        if @httpserv.working_count > 0
          sleep 0.2
          next
        end
        
        yield
        break
      end
    ensure
      self.unpause
    end
  end
  
  def working?
    sess_arr = @httpserv.http_sessions
    sess_arr.each do |sess|
      if sess.working
        return true
      end
    end
    
    return false
  end
  
  def self.data
    raise "Could not register current thread." if !Thread.current[:knjappserver]
    return Thread.current[:knjappserver]
  end
  
  def has_session?(args)
    ip = args[:ip].to_s
    idhash = args[:idhash].to_s
    
    return false if !@sessions.has_key?(ip) or !@sessions[ip].has_key?(idhash)
    return true
  end
  
  def session_fromid(args)
    ip = args[:ip].to_s
    idhash = args[:idhash].to_s
    ip = "bot" if idhash == "bot"
    
    if !@sessions.has_key?(ip) or !@sessions[ip].has_key?(idhash)
      @sessions[ip] = {} if !@sessions.has_key?(ip)
      @sessions[ip][idhash] = {
        :dbobj => @ob.add(:Session, {
          :idhash => idhash,
          :ip => ip
        }),
        :hash => {}
      }
    end
    
    @sessions[ip][idhash][:time_lastused] = Time.now
    return @sessions[ip][idhash]
  end
  
  def trans(obj, key)
    args = {}
    args[:locale] = _session[:locale] if _session[:locale] and !args[:locale]
    args[:locale] = _httpsession.data[:locale] if _httpsession.data[:locale] and !args[:locale]
    @translations.get(obj, key, args)
  end
  
  def trans_set(obj, values)
    args = {}
    args[:locale] = _session[:locale] if _session[:locale] and !args[:locale]
    args[:locale] = _httpsession.data[:locale] if _httpsession.data[:locale] and !args[:locale]
    @translations.set(obj, values, args)
  end
  
  def trans_del(obj)
    @translations.delete(obj)
  end
  
  def import(filepath)
    _httpsession.eruby.import(filepath)
  end
  
  def update_db
    require "rubygems"
    require "knjdbrevision"
    
    dbschemapath = "#{File.dirname(__FILE__)}/../files/database_schema.rb"
    raise "'#{dbschemapath}' did not exist." if !File.exists?(dbschemapath)
    require dbschemapath
    raise "No schema-variable was spawned." if !$tables
    
    dbpath = "#{File.dirname(__FILE__)}/../files/database.sqlite3"
    dbrev = Knjdbrevision.new
    dbrev.init_db($tables, @db)
  end
  
  def join
    return false if !@httpserv or @httpserv.thread_accept
    @httpserv.thread_accept.join
  end
  
  def define_magic_var(method_name, var)
    @magic_vars[method_name] = var
    
    if !Object.respond_to?(method_name)
      Object.send(:define_method, method_name) do
        return Thread.current[:knjappserver][:kas].magic_vars[method_name] if Thread.current[:knjappserver] and Thread.current[:knjappserver][:kas]
        return $knjappserver[:knjappserver].magic_vars[method_name] if $knjappserver and $knjappserver[:knjappserver]
        Knj::Php.print_r(Thread.current[:knjappserver])
        raise "Could not figure out the object: '#{method_name}'."
      end
    end
  end
end