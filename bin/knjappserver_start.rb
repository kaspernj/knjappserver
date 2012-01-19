#!/usr/bin/env ruby

require "#{File.dirname(__FILE__)}/../lib/knjappserver.rb"

knjrbfw_path = ""

ARGV.each do |arg|
  if arg == "--active_support"
    ARGV.delete(arg)
    require "active_support"
    require "active_support/core_ext"
  elsif match = arg.match(/--knjrbfw_path=(.+)/)
    knjrbfw_path = match[1]
    ARGV.delete(arg)
  else
    print "Unknown argument: '#{arg}'.\n"
    exit
  end
end

require "#{knjrbfw_path}knjrbfw"

filepath = File.dirname(__FILE__) + "/../lib/"

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