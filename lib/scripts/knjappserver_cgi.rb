#!/usr/bin/env ruby1.9.1

time_begin = Time.now

#This scripts start an appserver, executes a HTTP-request and terminates.
#Good for programming appserver-supported projects without running an appserver all the time,
#but really slow because of startup for every request.

class Cgi_is_retarded
  def env_table
    return ENV
  end
  
  def request_method
    return ENV["REQUEST_METHOD"]
  end
  
  def content_type
    return ENV["CONTENT_TYPE"]
  end
  
  def cgi
    @cgi = CGI.new if !@cgi
    return @cgi
  end
  
  def params
    return self.cgi.params
  end
  
  def print(arg)
    Kernel.print arg.to_s
  end
end

class Knjappserver
  def self.convert_fcgi_post(params)
    post_hash = {}
    
    params.each do |key, val|
      post_hash[key] = val.first
    end
    
    return post_hash
  end
end

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
  
  #Spawn appserver.
  knjappserver_conf = {
    :cmdline => false,
    :events => false,
    :cleaner => false,
    :dbrev => false,
    :mail_require => false,
    :port => 0 #Ruby picks random port and we get the actual port after starting the appserver.
  }.merge(Knjappserver::CGI_CONF["knjappserver"])
  knjappserver = Knjappserver.new(knjappserver_conf)
  knjappserver.start
  port = knjappserver.port
  
  
  #Make request.
  http = Knj::Http2.new(:host => "localhost", :port => port)
  
  
  #Spawn CGI-variable to emulate FCGI part.
  cgi = Cgi_is_retarded.new
  
  
  #The rest is copied from the FCGI-part.
  headers = {}
  cgi.env_table.each do |key, val|
    if key[0, 5] == "HTTP_" and key != "HTTP_KNJAPPSERVER_CGI_CONFIG"
      key = Knj::Php.ucwords(key[5, key.length].gsub("_", " ")).gsub(" ", "-")
      headers[key] = val
    end
  end
  
  #Make request.
  if cgi.env_table["PATH_INFO"].length > 0 and cgi.env_table["PATH_INFO"] != "/"
    url = cgi.env_table["PATH_INFO"][1, cgi.env_table["PATH_INFO"].length]
  else
    url = "index.rhtml"
  end
  
  if cgi.env_table["QUERY_STRING"].to_s.length > 0
    url << "?#{cgi.env_table["QUERY_STRING"]}"
  end
  
  #cgi.print "Content-Type: text/html\r\n"
  #cgi.print "\r\n"
  #cgi.print Knj::Php.print_r(cgi.params, true)
  
  if cgi.request_method == "POST" and cgi.content_type.to_s.downcase.index("multipart/form-data") != nil
    count = 0
    http.post_multipart(url, Knjappserver.convert_fcgi_post(cgi.params), {
      :default_headers => headers,
      :cookies => false,
      :on_content => proc{|line|
        cgi.print(line) if count > 0
        count += 1
      }
    })
  elsif cgi.request_method == "POST"
    count = 0
    http.post(url, Knjappserver.convert_fcgi_post(cgi.params), {
      :default_headers => headers,
      :cookies => false,
      :on_content => proc{|line|
        cgi.print(line) if count > 0
        count += 1
      }
    })
  else
    count = 0
    http.get(url, {
      :default_headers => headers,
      :cookies => false,
      :on_content => proc{|line|
        cgi.print(line) if count > 0
        count += 1
      }
    })
  end
rescue Exception => e
  knjappserver.stop
  
  print "Content-Type: text/html\r\n"
  print "\n\n"
  print Knj::Errors.error_str(e, {:html => true})
end