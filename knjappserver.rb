#!/usr/bin/env ruby

require "active_support"
require "active_support/core_ext"

$knjfwpath = "/home/kaspernj/Ruby/sc2replays.dk_test/include/"
require "#{$knjfwpath}knj/autoload"
require "#{$knjfwpath}knj/event_filemod"
include Knj

$knjappserver = {
	:path => Php.realpath(File.dirname(__FILE__))
}

Os.chdir_file(Php.realpath(__FILE__))

class Knjappserver
	autoload :Httpserver, "#{$knjappserver[:path]}/include/class_httpserver"
	autoload :Httpsession, "#{$knjappserver[:path]}/include/class_httpsession"
	autoload :Session, "#{$knjappserver[:path]}/include/class_session"
	autoload :Session_accessor, "#{$knjappserver[:path]}/include/class_session_accessor"
	
	attr_reader :config, :httpserv, :db, :ob, :translations, :cleaner, :should_restart
	
	def initialize(config)
		@should_restart = false
		@mod_events = {}
		
		@mod_files = {}
		@mod_event = Event_filemod.new(:wait => 2, :paths => [Php.realpath(__FILE__)]) do |event, path|
			print "File changed - restart server: #{path}\n"
			@should_restart = true
			@mod_event.destroy
		end
		
		self.loadfile "#{$knjappserver[:path]}/include/class_cleaner.rb"
		self.loadfile "#{$knjappserver[:path]}/include/class_session_accessor.rb"
		
		@config = config
		@db = @config[:db]
		@ob = Objects.new(
			:db => db,
			:class_path => Php.realpath(File.dirname(__FILE__)) + "/include",
			:module => Knjappserver,
			:extra_args => [self]
		)
		
		@sessions = {}
		@ob.list(:Session).each do |session|
			@sessions[session[:idhash]] = session
		end
		
		@httpserv = Httpserver.new(self)
		@translations = Knj::Translations.new(
			:db => @db
		)
		@cleaner = Cleaner.new(self)
	end
	
	def loadfile(fpath)
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
	
	def self.data
		return Thread.current[:knjappserver]
	end
	
	def session_fromid(idhash)
		if !@sessions[idhash]
			@sessions[idhash] = Knjappserver::Session.add(self, {
				:idhash => idhash
			})
		end
		
		return @sessions[idhash]
	end
	
	def trans(obj, key)
		args = {}
		args[:locale] = _httpsession.data[:locale] if _httpsession.data[:locale]
		args[:locale] = _session.data[:locale] if _httpsession.data[:locale] and !args[:locale]
		
		_kas.translations.get(obj, key, args)
	end
	
	def trans_set(obj, values)
		args = {}
		args[:locale] = _httpsession.data[:locale] if _httpsession.data[:locale]
		_kas.translations.set(obj, values, args)
	end
	
	def trans_del(obj)
		_kas.translations.delete(obj)
	end
end

def _cookie
	return Knjappserver.data[:cookie]
end

def _get
	return Knjappserver.data[:get]
end

def _post
	return Knjappserver.data[:post]
end

def _session
	return Knjappserver.data[:httpsession].session.accessor
end

def _server
	return Knjappserver.data[:meta]
end

def _httpsession
	return Knjappserver.data[:httpsession]
end

def _meta
	return Knjappserver.data[:meta]
end

def _kas
	return Knjappserver.data[:httpsession].kas
end

#query_str = "show[4][1][test]=hmm1&show[5][2][test]=hmm2&show[array][]=test1&show[array][]=test2"
#get = Web.parse_urlquery(query_str)
#Php.print_r(get)
#print get["show"][4][1]["test"] + "\n"


print "Starting knjAppServer.\n"
require "./conf/conf"
