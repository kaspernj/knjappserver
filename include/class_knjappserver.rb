require "#{File.dirname(__FILE__)}/class_knjappserver_logging"
require "#{File.dirname(__FILE__)}/class_knjappserver_threadding"
require "#{File.dirname(__FILE__)}/class_knjappserver_web"

class Knjappserver
	attr_reader :config, :httpserv, :db, :db_handler, :ob, :translations, :paused, :cleaner, :should_restart, :mod_event, :paused, :db_handler, :gettext, :sessions, :logs_access_pending
	attr_accessor :served, :should_restart
	
	def initialize(config)
		require "webrick"
		
		@config = config
		@paused = 0
		@should_restart = false
		@mod_events = {}
		@served = 0
		@mod_files = {}
		@logs_access_pending = []
		
		paths = [
			"#{$knjappserver[:path]}/knjappserver.rb",
			"#{$knjappserver[:path]}/include/class_knjappserver.rb",
			"#{$knjappserver[:path]}/include/class_customio.rb"
		]
		
		if @config[:autorestart]
			print "Auto restarting.\n"
			@mod_event = Knj::Event_filemod.new(:wait => 2, :paths => paths) do |event, path|
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
			"#{$knjappserver[:path]}/include/class_log.rb",
			"#{$knjappserver[:path]}/include/class_log_access.rb",
			"#{$knjappserver[:path]}/include/class_log_data_value.rb",
			"#{$knjappserver_config["knjrbfw"]}knj/objects.rb",
			"#{$knjappserver_config["knjrbfw"]}knj/web.rb",
			"#{$knjappserver_config["knjrbfw"]}knj/datet.rb",
			"#{$knjappserver_config["knjrbfw"]}knj/thread.rb",
			"#{$knjappserver_config["knjrbfw"]}knj/threadhandler.rb",
			"#{$knjappserver_config["knjrbfw"]}knj/knjdb/libknjdb.rb"
		]
		files.each do |file|
			if @config[:autorestart]
				self.loadfile(file)
			else
				require file
			end
		end
		
		@db = @config[:db]
		@ob = Knj::Objects.new(
			:db => db,
			:class_path => "#{$knjappserver[:path]}/include",
			:module => Knjappserver,
			:datarow => true,
			:knjappserver => self
		)
		
		if @config[:httpsession_db_args]
			@db_handler = Knj::Db.new(@config[:httpsession_db_args])
		end
		
		@httpserv = Knjappserver::Httpserver.new(self)
		@translations = Knj::Translations.new(:db => @db)
		@cleaner = Knjappserver::Cleaner.new(self)
		
		if @config[:locales_root]
			@gettext = Knj::Gettext_threadded.new("dir" => config[:locales_root])
		end
		
		Knj::Thread.new do
			loop do
				sleep 10
				next if @logs_access_pending.length <= 0
				flush_access_log
			end
		end
		
		self.register_run
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
		if !@sessions
			@sessions = {}
			@ob.list(:Session).each do |session|
				@sessions[session[:ip].to_s] = {} if !@sessions.has_key?(session[:ip].to_s)
				@sessions[session[:ip].to_s][session[:idhash].to_s] = {
					:dbobj => session,
					:hash => {}
				}
			end
		end
		
		Thread.current[:knjappserver] = {:kas => self} if !Thread.current[:knjappserver]
		
		if @config[:autoload]
			print "Autoloading #{@config[:autoload]}\n"
			require @config[:autoload]
		end
		
		@httpserv.start
	end
	
	def register_run
		run_file = Knj::Php.realpath("#{File.dirname(__FILE__)}/../files/run") + "/knjappserver"
		Knj::Php.file_put_contents(run_file, Process.pid)
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
		script_cmd = "#{Knj::Os.homedir}/Ruby/knjdbrevision/knjdbrevision.rb"
		raise "knjdbrevision doesnt exist in #{script_cmd}." if !File.exists?(script_cmd)
		
		script_cmd = "/usr/bin/ruby1.9.1 #{script_cmd}"
		script_cmd += " -r #{Knj.dirname(__FILE__)}/../files/database_schema.rb"
		
		@db.opts.each do |key, val|
			val = "mysql" if key == :type and val == "mysql2"
			script_cmd += " -d #{key}=#{val}"
		end
		
		print %x[#{script_cmd}]
	end
	
	def handle_error(e)
		if !Thread.current[:knjappserver] or !Thread.current[:knjappserver][:httpsession]
			STDOUT.print "Error: "
			STDOUT.puts e.inspect
			STDOUT.print "\n"
			STDOUT.puts e.backtrace
			STDOUT.print "\n\n"
		end
		
		if @config.has_key?(:smtp_args) and @config[:error_report_emails]
			@config[:error_report_emails].each do |email|
				html = "An error occurred." + "<br /><br />"
				html += "<b>#{e.class.name.html}: #{e.message.html}</b><br /><br />"
				
				e.backtrace.each do |line|
					html += line.html + "<br />"
				end
				
				html += "<br />Post:<br /><pre>#{Knj::Php.print_r(_post, true)}</pre>" if _post
				html += "<br />Get:<br /><pre>#{Knj::Php.print_r(_get, true)}</pre>" if _get
				html += "<br />Server:<br /><pre>#{Knj::Php.print_r(_server, true).html}</pre>" if _server
				
				mail = Knj::Mailobj.new(@config[:smtp_args])
				mail.to = email
				mail.subject = sprintf("Error @ %s", @config[:title])
				mail.html = html
				mail.from = @config[:error_report_from]
				mail.send
			end
		end
	end
end