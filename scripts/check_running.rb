#!/usr/bin/env ruby1.9.1

# This script checks if the knjappserver is running - if not it forks and start it.

require "knj/autoload"
Knj::Os.chdir_file(__FILE__)
Dir.chdir("../")

run_file = "files/run/knjappserver"
count = 0

if File.exists?(run_file)
	pid = File.read(run_file)
	count = Knj::Unix_proc.list("pids" => [pid]).length
end

exit if count > 0

begin
	options = {
		:command => "ruby1.9.1 knjappserver.rb"
	}
	OptionParser.new do |opts|
		opts.banner = "Usage: knjappserver.rb [options]"
		
		opts.on("--command=[cmd]", "Run verbosely.") do |cmd|
			options[:command] = cmd
		end
	end.parse!
rescue OptionParser::InvalidOption => e
	Knj::Php.die(e.message + "\n")
end

exec(options[:command]) if fork.nil?