#!/usr/bin/env ruby

require "knj/autoload"
include Knj
Os.chdir_file(__FILE__)

class Knjappserver
	autoload :Httpserver, "include/class_httpserver"
	autoload :Httpsession, "include/class_httpsession"
	
	attr_reader :config, :httpserv
	
	def initialize(config)
		@config = config
		@httpserv = Httpserver.new(self)
	end
	
	def start
		@httpserv.start
	end
	
	def self.data
		return Thread.current[:knjappserver]
	end
end

#query_str = "show[4][1][test]=hmm1&show[5][2][test]=hmm2&show[array][]=test1&show[array][]=test2"
#get = Web.parse_urlquery(query_str)
#Php.print_r(get)
#print get["show"][4][1]["test"] + "\n"



require "conf/conf.rb"