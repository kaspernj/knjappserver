#!/usr/bin/env ruby

ARGV.each do |arg|
	if arg == "--active_support"
		ARGV.delete(arg)
		require "rubygems"
		require "active_support"
		require "active_support/core_ext"
	end
end

filepath = File.dirname(__FILE__) + "/"

require "#{filepath}conf/conf_vars"
require "#{$knjappserver_config["knjrbfw"]}knj/autoload"
require "#{$knjappserver_config["knjrbfw"]}knj/ext/webrick"

$knjappserver = {
	:path => Knj::Php.realpath(File.dirname(__FILE__))
}

Knj::Os.chdir_file(Knj::Php.realpath(__FILE__))
require "#{filepath}include/class_knjappserver.rb"

#Lets hack the $stdout to make it possible to have many running threads that all uses print.
require "#{filepath}include/class_customio.rb"
cio = Knjappserver::CustomIO.new
$stdout = cio

Knj::Thread.new do
	loop do
		sleep 30
		GC.enable if RUBY_ENGINE != "jruby"
		GC.start
		ObjectSpace.garbage_collect
	end
end

print "Starting knjAppServer.\n"
require "./include/magic_methods.rb"
require "./conf/conf"