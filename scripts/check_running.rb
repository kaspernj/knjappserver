#!/usr/bin/env ruby

# This script checks if the knjappserver is running - if not it forks and start it.

require "knj/autoload"
include Knj
Os.chdir_file(__FILE__)

procs = Knj::Unix_proc.list(
	"grep" => "knjappserver"
)

count = 0
procs.each do |proc|
	if proc.data["app"] != "check_running.rb"
		count += 1
	end
end

if count <= 0
	filepath = Php.realpath("../knjappserver.rb")
	exec("ruby #{Strings.unixsafe(filepath)}") if fork.nil?
end