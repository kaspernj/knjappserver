#!/usr/bin/env ruby

# This script checks if the knjappserver is running - if not it forks and start it.

require "knj/autoload"
include Knj
Os.chdir_file(__FILE__)

procs = Knj::Unix_proc.list(
	"grep" => "knjappserver"
)

if procs.empty?
	filepath = Php.realpath("../knjappserver.rb")
	exec("ruby #{Strings.unixsafe(filepath)}") if fork.nil?
end