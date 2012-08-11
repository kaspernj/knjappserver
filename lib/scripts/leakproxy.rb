#!/usr/bin/env ruby

data = Marshal.load($stdin.gets)

require "#{data[:knjrbfw_path]}knjrbfw"
require "#{File.dirname(__FILE__)}/../knjappserver.rb"
require "#{File.dirname(__FILE__)}/../include/class_knjappserver_leakproxy_client.rb"

require "#{$knjpath}/process"

process = Knj::Process.new(
  :in => $stdin,
  :out => $stdout,
  :listen => true,
  :on_rec => proc{|d|
    d.answer("unknown command")
  }
)



process.send(
  "type" => "print",
  "msg" => "Test?\n"
)

process.join