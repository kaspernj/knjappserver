#!/usr/bin/env ruby1.9.1

# This script checks if the knjappserver is running - if not it forks and start it.

require "knj/autoload"
Knj::Os.chdir_file(__FILE__)
Dir.chdir("../")

begin
	options = {
		:command => "ruby knjappserver_start.rb",
		:title => "knjappserver",
		:forking => true
	}
	OptionParser.new do |opts|
		opts.banner = "Usage: knjappserver.rb [options]"
		
		opts.on("--command=[cmd]", "Run verbosely.") do |cmd|
			options[:command] = cmd
		end
		
		opts.on("--title=[title]", "The title of the appserver that should be checked for.") do |title|
      options[:title] = title
		end
		
		opts.on("--forking=[forkval]", "If you want the script to fork or not.") do |forking|
      if forking.to_i >= 1
        options[:forking] = true
      else
        options[:forking] = false
      end
		end
	end.parse!
rescue OptionParser::InvalidOption => e
	Knj::Php.die(e.message + "\n")
end

if !options[:title]
  print "No title was given.\n"
  exit
end

if !options[:command]
  print "No command to execute was given.\n"
  exit
end

require "tmpdir"
tmpdir = "#{Dir.tmpdir}/knjappserver"
tmppath = "#{tmpdir}/run_#{options[:title]}"
count = 0

if File.exists?(tmppath)
  pid = File.read(tmppath)
  count = Knj::Unix_proc.list("pids" => [pid]).length
end

exit if count > 0

if options[:forking]
  exec(options[:command]) if fork.nil?
else
  exec(options[:command])
end