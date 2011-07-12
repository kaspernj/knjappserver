require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Knjappserver" do
  it "should be able to start a sample-server" do
    require "rubygems"
    require "knjappserver"
    require "knjrbfw"
    require "knj/autoload"
    require "tmpdir"
    
    db_path = "#{Dir.tmpdir}/knjappserver_rspec.sqlite3"
    File.unlink(db_path) if File.exists?(db_path)
    
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
  
  it "should be able to join the server so other tests can be made manually." do
    $appserver.join
  end
end
