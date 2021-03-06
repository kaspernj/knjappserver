require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Knjappserver" do
  it "should be able to start a sample-server" do
    require "rubygems"
    require "knjappserver"
    require "knjrbfw"
    require "sqlite3" if RUBY_ENGINE != "jruby"
    
    db_path = "#{Knj::Os.tmpdir}/knjappserver_rspec.sqlite3"
    File.unlink(db_path) if File.exists?(db_path)
    
    begin
      db = Knj::Db.new(
        :type => "sqlite3",
        :path => db_path,
        :return_keys => "symbols"
      )
    rescue => e
      STDOUT.puts e.inspect
      STDOUT.puts e.backtrace
      
      raise e
    end
    
    erbhandler = Knjappserver::ERBHandler.new
    
    if RUBY_ENGINE == "jruby"
      mail_require = false
    else
      mail_require = true
    end
    
    $appserver = Knjappserver.new(
      :debug => false,
      :autorestart => false,
      :title => "SpecTest",
      :port => 1515,
      :doc_root => "#{File.dirname(__FILE__)}/../lib/pages",
      :locales_gettext_funcs => true,
      :locale_default => "da_DK",
      :db => db,
      :mail_require => mail_require
    )
    
    $appserver.vars[:test] = "kasper"
    $appserver.define_magic_var(:_testvar1, "Kasper")
    $appserver.define_magic_var(:_testvar2, "Johansen")
    $appserver.start
  end
  
  it "should be able to handle a GET-request." do
    #Check that we are able to perform a simple GET request and get the correct data back.
    require "knj/http"
    $http = Knj::Http.new("host" => "localhost", "port" => 1515)
    data = $http.get("/spec.rhtml")
    raise "Unexpected HTML: '#{data["data"]}'." if data["data"].to_s != "Test"
    
    #Check that URL-decoding are being done.
    data = $http.get("/spec.rhtml?choice=check_get_parse&value=#{Knj::Web.urlenc("gfx/nopic.png")}")
    raise "Unexpected HTML: '#{data["data"]}'." if data["data"].to_s != "gfx/nopic.png"
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
    data = $http.get("/spec.rhtml?choice=test_cookie")
    raise data["data"] if data["data"].to_s.length > 0
    
    data = $http.get("/spec.rhtml?choice=get_cookies")
    parsed = JSON.parse(data["data"])
    
    raise "Unexpected value for 'TestCookie': '#{parsed["TestCookie"]}'." if parsed["TestCookie"] != "TestValue"
    raise "Unexpected value for 'TestCookie2': '#{parsed["TestCookie2"]}'." if parsed["TestCookie2"] != "TestValue2"
    raise "Unexpected value for 'TestCookie3': '#{parsed["TestCookie3"]}'." if parsed["TestCookie3"] != "TestValue 3 "
  end
  
  it "should be able to run the rspec_threadded_content test correctly." do
    data = $http.get("/spec_threadded_content.rhtml")
    
    if data["data"] != "12345678910"
      raise data["data"].to_s
    end
  end
  
  it "should be able to add a timeout." do
    $break_timeout = false
    timeout = $appserver.timeout(:time => 1) do
      $break_timeout = true
    end
    
    Timeout.timeout(2) do
      loop do
        break if $break_timeout
        sleep 0.1
      end
    end
  end
  
  it "should be able to stop a timeout." do
    $timeout_runned = false
    timeout = $appserver.timeout(:time => 1) do
      $timeout_runned = true
    end
    
    sleep 0.5
    timeout.stop
    
    begin
      Timeout.timeout(1.5) do
        loop do
          raise "The timeout ran even though stop was called?" if $timeout_runned
          sleep 0.1
        end
      end
    rescue Timeout::Error
      #the timeout didnt run - and it shouldnt so dont do anything.
    end
  end
  
  it "should be able to join threads tarted from _kas.thread." do
    data = $http.get("/spec_thread_joins.rhtml")
    raise data["data"] if data["data"].to_s != "12345"
  end
  
  it "should be able to properly parse special characters in post-requests." do
    data = $http.post("/spec_post.rhtml", {
      "test" => "123+456%789%20"
    })
    raise data["data"] if data["data"] != "123+456%789%20"
  end
  
  it "should be able to do logging" do
    class ::TestModels
      class Person < Knj::Datarow
        
      end
    end
    
    Knj::Db::Revision.new.init_db("db" => $appserver.db, "schema" => {
      "tables" => {
        "Person" => {
          "columns" => [
            {"name" => "id", "type" => "int", "autoincr" => true, "primarykey" => true},
            {"name" => "name", "type" => "varchar"}
          ]
        }
      }
    })
    
    ob = Knj::Objects.new(
      :db => $appserver.db,
      :datarow => true,
      :require => false,
      :module => ::TestModels
    )
    
    person = ob.add(:Person, :name => "Kasper")
    
    $appserver.log("This is a test", person)
    logs = $appserver.ob.list(:Log, "object_lookup" => person).to_a
    raise "Expected count to be 1 but got: #{logs.length}" if logs.length != 1
    
    $appserver.logs_delete(person)
    
    logs = $appserver.ob.list(:Log, "object_lookup" => person).to_a
    raise "Expected count to be 0 but got: #{logs.length}" if logs.length != 0
  end
  
  it "should be able to stop." do
    $appserver.stop
  end
end
