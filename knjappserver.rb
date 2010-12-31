#!/usr/bin/env ruby

require "rubygems"
require "active_support"
require "active_support/core_ext"
require "gettext"

filepath = File.dirname(__FILE__) + "/"

require "#{filepath}conf/conf_vars"
require "#{$knjappserver_config["knjrbfw"]}knj/autoload"
include Knj

$knjappserver = {
	:path => Php.realpath(File.dirname(__FILE__))
}

Os.chdir_file(Php.realpath(__FILE__))
require "#{filepath}include/class_knjappserver.rb"

#Lets hack the $stdout to make it possible to have many running threads that all uses print.
require "#{filepath}include/class_customio.rb"
$stdout = Knjappserver::CustomIO.new

print "Starting knjAppServer.\n"
require "./include/magic_methods.rb"
require "./conf/conf"