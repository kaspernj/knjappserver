#!/usr/bin/env ruby1.9.1

#This scripts start an appserver, executes a HTTP-request and terminates.
#Good for programming appserver-supported projects without running an appserver all the time,
#but really slow because of startup for every request.

begin
  require "knj/autoload"
  require "#{File.dirname(Knj::Os.realpath(__FILE__))}/../knjappserver.rb"

  raise "No HTTP_KNJAPPSERVER_CGI_CONFIG-header was given." if !ENV["HTTP_KNJAPPSERVER_CGI_CONFIG"]
  require ENV["HTTP_KNJAPPSERVER_CGI_CONFIG"]

  begin
    conf = Knjappserver::CGI_CONF
  rescue NameError
    raise "No 'Knjappserver::CGI_CONF'-constant was spawned by '#{ENV["HTTP_KNJAPPSERVER_CGI_CONFIG"]}'."
  end


  headers = {}
  ENV.each do |key, val|
    if key[0, 5] == "HTTP_" and key != "HTTP_KNJAPPSERVER_CGI_CONFIG"
      #key = key[5, key.length]
      key = Knj::Php.ucwords(key[5, key.length].gsub("_", " ")).gsub(" ", "-")
      
      headers[key] = val
    end
  end

  knjappserver_conf = Knjappserver::CGI_CONF["knjappserver"]
  knjappserver_conf[:cmdline] = false
  knjappserver_conf[:port] = 0 #Ruby picks random port and we get the actual port after starting the appserver.

  knjappserver = Knjappserver.new(knjappserver_conf)
  knjappserver.start
  port = knjappserver.port


  #Make request.
  http = Knj::Http2.new(:host => "localhost", :port => port)

  count = 0
  http.get(ENV["PATH_INFO"][1, ENV["PATH_INFO"].length], {
    :default_headers => headers,
    :cookies => false,
    :on_content => proc{|line|
      print line if count > 0
      count += 1
    }
  })
rescue Exception => e
  print "Content-Type: text/html\r\n"
  print "\n\n"
  print Knj::Errors.error_str(e, {:html => true})
end