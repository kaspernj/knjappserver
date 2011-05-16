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
			"#{$knjappserver[:path]}/include/class_log_access.rb",
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
			:datarow => true
		)
		
		if @config[:httpsession_db_args]
			@db_handler = Knj::Threadhandler.new
			
			@db_handler.on_spawn_new do
				db = Knj::Db.new(@config[:httpsession_db_args])
				db #return db to the spawner process - dont remove - knj
			end
			
			@db_handler.on_inactive do |data|
				data[:obj].close
			end
			
			@db_handler.on_activate do |data|
				data[:obj].reconnect
			end
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
	end
	
	def flush_access_log
		ins_arr = @logs_access_pending
		@logs_access_pending = []
		inserts = []
		inserts_links = []
		
		data_cache = {}
		q_data = @db.query("SELECT id, id_hash FROM Log_data")
		while d_data = q_data.fetch
			data_cache[d_data[:id_hash]] = d_data[:id]
		end
		
		ins_arr.each do |ins|
			gothrough = [
				{
					:col => :get_keys_data_id,
					:hash => ins[:get],
					:type => :keys
				},{
					:col => :get_values_data_id,
					:hash => ins[:get],
					:type => :values
				},{
					:col => :post_keys_data_id,
					:hash => ins[:post],
					:type => :keys
				},{
					:col => :post_values_data_id,
					:hash => ins[:post],
					:type => :values
				},{
					:col => :cookie_keys_data_id,
					:hash => ins[:cookie],
					:type => :keys
				},{
					:col => :cookie_values_data_id,
					:hash => ins[:cookie],
					:type => :values
				},{
					:col => :meta_keys_data_id,
					:hash => ins[:meta],
					:type => :keys
				},{
					:col => :meta_values_data_id,
					:hash => ins[:meta],
					:type => :values
				}
			]
			ins_hash = {
				:session_id => ins[:session_id],
				:date_request => ins[:date_request]
			}
			
			gothrough.each do |data|
				if data[:type] == :keys
					hash = Knj::ArrayExt.hash_keys_hash(data[:hash])
				else
					hash = Knj::ArrayExt.hash_values_hash(data[:hash])
				end
				
				data_id = data_cache[hash]
				if !data_id
					data_id = @db.insert(:Log_data, {"id_hash" => hash}, {:return_id => true})
					data_cache[hash] = data_id
					
					link_count = 0
					data[:hash].keys.sort.each do |key|
						if data[:type] == :keys
							ins_data = key
						else
							ins_data = data[:hash][key]
						end
						
						data_value = @db.single(:Log_data_value, {"value" => ins_data})
						if data_value
							data_value_id = data_value[:id]
						else
							data_value_id = @db.insert(:Log_data_value, {"value" => ins_data}, {:return_id => true})
						end
						
						inserts_links << {:no => link_count, :data_id => data_id, :value_id => data_value_id}
						link_count += 1
					end
				end
				
				ins_hash[data[:col]] = data_id
			end
			
			hash = Knj::ArrayExt.array_hash(ins[:ips])
			data_id = data_cache[hash]
			
			if !data_id
				data_id = @db.insert(:Log_data, {"id_hash" => hash}, {:return_id => true})
				data_cache[hash] = data_id
				
				link_count = 0
				ins[:ips].each do |ip|
					data_value = @db.single(:Log_data_value, {"value" => ip})
					
					if data_value
						data_value_id = data_value[:id]
					else
						data_value_id = @db.insert(:Log_data_value, {"value" => ip}, {:return_id => true})
					end
					
					inserts_links << {:no => link_count, :data_id => data_id, :value_id => data_value_id}
					link_count += 1
				end
			end
			
			ins_hash[:ip_data_id] = data_id
			inserts << ins_hash
		end
		
		@db.insert_multi(:Log_access, inserts)
		@db.insert_multi(:Log_data_link, inserts_links)
		@ob.unset_class([:Log_access, :Log_data, :Log_data_link, :Log_data_value])
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
	
	def redirect(url, args = {})
		return Knj::Web.redirect(url, args)
	end
	
	def alert(msg)
		return Knj::Web.alert(msg)
	end
	
	def back
		return Knj::Web.back
	end
end