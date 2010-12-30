#!/usr/bin/env ruby

require "rubygems"
require "active_support"
require "active_support/core_ext"
require "gettext"

require File.dirname(__FILE__) + "/conf/conf_vars"
require "#{$knjappserver_config["knjrbfw"]}knj/autoload"
include Knj

$knjappserver = {
	:path => Php.realpath(File.dirname(__FILE__))
}

Os.chdir_file(Php.realpath(__FILE__))

class Knjappserver
	attr_reader :config, :httpserv, :db, :ob, :translations, :cleaner, :should_restart, :mod_event, :paused
	
	def initialize(config)
		@paused = 0
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
		self.loadfile "#{$knjappserver[:path]}/include/class_httpserver.rb"
		self.loadfile "#{$knjappserver[:path]}/include/class_httpsession.rb"
		self.loadfile "#{$knjappserver[:path]}/include/class_session.rb"
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
			@sessions[session[:idhash]] = {
				:dbobj => session,
				:hash => {}
			}
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
		return Thread.current[:knjappserver]
	end
	
	def session_fromid(idhash)
		if !@sessions[idhash]
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

#Lets hack the $stdout to make it possible to have many running threads that all uses print.
class Knjappserver::CustomIO < StringIO
	def print(str)
		thread = Thread.current
		
		if thread and thread[:knjappserver]
			#STDOUT.print("Print: " + str)
			return thread[:knjappserver][:httpsession].out.print(str)
		else
			return STDOUT.print(str)
		end
	end
	
	def <<(str)
		self.print(str)
	end
	
	def write(str)
		self.print(str)
	end
end

$stdout = Knjappserver::CustomIO.new

print "Starting knjAppServer.\n"
require "./include/magic_methods.rb"
require "./conf/conf"