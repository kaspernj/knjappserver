require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Knjappserver" do
  it "should be able to start a sample-server" do
    require "rubygems"
    require "knjappserver"
    require "knjrbfw"
    require "tmpdir"
    
    db_path = "#{Dir.tmpdir}/knjappserver_rspec.sqlite3"
    File.unlink(db_path) if File.exists?(db_path)
    
    require "knj/knjdb/libknjdb.rb"
    require "sqlite3"
    db = Knj::Db.new(
      :type => "sqlite3",
      :path => db_path,
      :return_keys => "symbols"
    )
    
    erbhandler = Knjappserver::ERBHandler.new
    
    $appserver = Knjappserver.new(
      :debug => false,
      :autorestart => false,
      :autoload => false,
      :verbose => false,
      :title => "knjTasks",
      :port => 1515,
      :host => "0.0.0.0",
      :default_page => "index.rhtml",
      :doc_root => "#{File.dirname(__FILE__)}/../lib/pages",
      :hostname => false,
      :default_filetype => "text/html",
      :engine_knjengine => true,
      :locales_gettext_funcs => true,
      :locale_default => "da_DK",
      :max_requests_working => 5,
      :filetypes => {
        :jpg => "image/jpeg",
        :gif => "image/gif",
        :png => "image/png",
        :html => "text/html",
        :htm => "text/html",
        :rhtml => "text/html",
        :css => "text/css",
        :xml => "text/xml",
        :js => "text/javascript"
      },
      :handlers => [
        {
          :file_ext => "rhtml",
          :callback => erbhandler.method(:erb_handler)
        },{
          :path => "/fckeditor",
          :mount => "/usr/share/fckeditor"
        }
      ],
      :db => db
    )
    
    $appserver.vars[:test] = "kasper"
    $appserver.define_magic_var(:_testvar1, "Kasper")
    $appserver.define_magic_var(:_testvar2, "Johansen")
    $appserver.update_db
    $appserver.start
  end
  
  it "should be able to mount FCKeditor dir to /usr/share/fckeditor" do
    
  end
  
  it "should be able to handle a GET-request." do
    require "knj/http"
    $http = Knj::Http.new("host" => "localhost", "port" => 1515)
    data = $http.get("/spec.rhtml")
    raise "Unexpected HTML: '#{data["data"]}'." if data["data"].to_s.strip != "Test"
  end
  
  it "should be able to handle a HEAD-request." do
    data = $http.head("/spec.rhtml")
    raise "HEAD-request returned content - it shouldnt?" if data["data"].to_s.length > 0
  end
  
  it "should be able to handle a POST-request." do
    data = $http.post("/spec.rhtml", {
      "postdata" => "Test post"
    })
    raise "POST-request did not return expected data: '#{data["data"]}'." if data["data"].to_s.strip != "Test post"
  end
  
  it "should be able to join the server so other tests can be made manually." do
    begin
      Timeout.timeout(1) do
        $appserver.join
        raise "Appserver didnt join."
      end
    rescue Timeout::Error
      #ignore.
    end
  end
  
  it "should be able to use the header-methods." do
    data = $http.get("/spec.rhtml")
    raise "Normal header data could not be detected." if data["response"].header["testheader"] != "NormalHeader"
    raise "Raw header data could not be detected." if data["response"].header["testraw"]!= "RawHeader"
  end
  
  it "should be able to set and get multiple cookies at the same time." do
    require "json"
    
    data = $http.get("/spec.rhtml?choice=test_cookie")
    raise data["data"] if data["data"].to_s.length > 0
    
    data = $http.get("/spec.rhtml?choice=get_cookies")
    parsed = Knj::Php.json_decode(data["data"])
    
    raise "Unexpected value for 'TestCookie': '#{parsed["TestCookie"]}'." if parsed["TestCookie"] != "TestValue"
    raise "Unexpected value for 'TestCookie2': '#{parsed["TestCookie2"]}'." if parsed["TestCookie2"] != "TestValue2"
    raise "Unexpected value for 'TestCookie3': '#{parsed["TestCookie3"]}'." if parsed["TestCookie3"] != "TestValue 3 "
  end
  
  it "should be able to stop." do
    $appserver.stop
  end
end
