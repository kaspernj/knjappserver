require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Knjappserver" do
  it "should be able to start a sample-server" do
    require "rubygems"
    require "knjappserver"
    require "knjrbfw"
    require "tmpdir"
    require "knj/autoload"
    
    db_path = "#{Dir.tmpdir}/knjappserver_rspec.sqlite3"
    File.unlink(db_path) if File.exists?(db_path)
    
    require "knj/knjdb/libknjdb.rb"
    #require "sqlite3" if RUBY_ENGINE != "jruby"
    
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
      :mail_require => mail_require,
      :leakproxy => true
    )
    
    $appserver.start
    $appserver.join
  end
  
  it "should be able to stop." do
    $appserver.stop
  end
end