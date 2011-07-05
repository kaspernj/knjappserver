#!/usr/bin/env ruby

require "rubygems"
require "knjappserver"
require "knjrbfw"

ARGV.each do |arg|
   if arg == "--active_support"
      ARGV.delete(arg)
      require "active_support"
      require "active_support/core_ext"
   end
end

filepath = File.dirname(__FILE__) + "/../lib/"

print "Test: #{$0}\n"

if File.exists?($0)
  conf_path = File.dirname($0) + "/../"
else
  conf_path = File.dirname(__FILE__) + "/../"
end

require "#{conf_path}conf/conf_vars"
require "webrick"
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

Thread.new do
	loop do
		sleep 30
		GC.enable if RUBY_ENGINE != "jruby"
		GC.enable
		GC.start
		ObjectSpace.garbage_collect
	end
end

print "Starting knjAppServer.\n"
require "#{conf_path}conf/conf"