class Knjappserver
	attr_reader :config, :httpserv, :db, :ob, :translations, :cleaner, :should_restart, :mod_event, :paused, :db_handler, :gettext, :sessions, :eruby
	attr_accessor :served
	
	def initialize(config)
		@config = config
		@paused = 0
		@should_restart = false
		@mod_events = {}
		@served = 0
		@eruby = Knj::Eruby.new
		
		@mod_files = {}
		paths = [
			"#{$knjappserver[:path]}/knjappserver.rb",
			"#{$knjappserver[:path]}/include/class_knjappserver.rb",
			"#{$knjappserver[:path]}/include/class_customio.rb"
		]
		
		if @config[:autorestart]
			@mod_event = Event_filemod.new(:wait => 2, :paths => paths) do |event, path|
				print "File changed - restart server: #{path}\n"
				@should_restart = true
				@mod_event.destroy
			end
		end
		
		files = [
			"#{$knjappserver[:path]}/include/class_cleaner.rb",
			"#{$knjappserver[:path]}/include/class_session_accessor.rb",
			"#{$knjappserver[:path]}/include/class_httpserver.rb",
			"#{$knjappserver[:path]}/include/class_httpsession.rb",
			"#{$knjappserver[:path]}/include/class_session.rb",
			"#{$knjappserver[:path]}/include/class_session_accessor.rb",
			"#{$knjappserver_config["knjrbfw"]}knj/objects.rb",
			"#{$knjappserver_config["knjrbfw"]}knj/web.rb",
			"#{$knjappserver_config["knjrbfw"]}knj/thread.rb",
			"#{$knjappserver_config["knjrbfw"]}knj/threadhandler.rb",
			"#{$knjappserver_config["knjrbfw"]}knj/knjdb/libknjdb.rb"
		]
		files.each do |file|
			if @config[:autorestart]
				self.loadfile file
			else
				require file
			end
		end
		
		@db = @config[:db]
		@ob = Objects.new(
			:db => db,
			:class_path => "#{$knjappserver[:path]}/include",
			:module => Knjappserver,
			:extra_args => [self]
		)
		
		@sessions = {}
		@ob.list(:Session).each do |session|
			@sessions[session[:idhash]] = {
				:dbobj => session,
				:hash => {}
			}
		end
		
		if @config[:httpsession_db_args]
			@db_handler = Knj::Threadhandler.new
			@db_handler.on_spawn_new do
				db = Knj::Db.new(@config[:httpsession_db_args])
				db
			end
		end
		
		@httpserv = Httpserver.new(self)
		@translations = Knj::Translations.new(
			:db => @db
		)
		@cleaner = Cleaner.new(self)
		
		if config[:locales_root]
			@gettext = Knj::Gettext_threadded.new(
				"dir" => config[:locales_root]
			)
		end
	end
	
	def loadfile(fpath)
		if !@config[:autorestart]
			require fpath
			return nil
		end
		
		rpath = Php.realpath(fpath)
		if !rpath or !File.exists?(rpath)
			raise "No such filepath: #{fpath}"
		end
		
		if @mod_files[rpath]
			return true
		end
		
		@mod_event.args[:paths] << rpath
		@mod_files = rpath
		
		require rpath
		return false
	end
	
	def start
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
		if @paused > 0
			return true
		end
		
		return false
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
	
	def session_fromid(idhash)
		if !@sessions.has_key?(idhash)
			@sessions[idhash] = {
				:dbobj => Knjappserver::Session.add(self, {
					:idhash => idhash
				}),
				:hash => {}
			}
		end
		
		return @sessions[idhash]
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
end