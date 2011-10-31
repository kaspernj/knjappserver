#!/usr/bin/env ruby1.9.1

Dir.chdir(File.dirname(__FILE__))
require "rubygems"
require "../knjappserver.rb"
require "knjrbfw"
require "erubis"
require "sqlite3" if RUBY_ENGINE != "jruby"
require "knj/autoload"

page = "benchmark.rhtml"
ARGV.each do |arg|
  if arg == "print"
    page = "benchmark_print.rhtml"
  else
    print "Unknown argument: #{arg}\n"
    exit
  end
end

db_path = "#{File.dirname(__FILE__)}/benchmark_db.sqlite3"

appsrv = Knjappserver.new(
  :debug => false,
  :port => 15081,
  :doc_root => "#{File.dirname(__FILE__)}/../pages",
  :db_args => {
    :type => "sqlite3",
    :path => db_path,
    :return_keys => "symbols"
  }
)
appsrv.start

count_requests = 0
1.upto(100) do |count_thread|
  Knj::Thread.new(count_thread) do |count_thread|
    print "Thread #{count_thread} started.\n"
    
    http = Knj::Http2.new(
      :host => "localhost",
      :port => 15081,
      :user_agent => "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.0.1; debugid:#{count_thread}) Gecko/20060111 Firefox/3.6.0.1",
      :debug => false
    )
    
    loop do
      http.get(page)
      count_requests += 1
    end
  end
end

loop do
  last_count = count_requests
  sleep 1
  counts_betw = count_requests - last_count
  print "#{counts_betw} /sec\n"
end

appsrv.join