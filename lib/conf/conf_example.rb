rpath = File.realpath(File.dirname(__FILE__) + "/../include/class_erbhandler.rb")
require rpath
erbhandler = Knjappserver::ERBHandler.new

dbargs = {
	:type => "mysql",
	:subtype => "mysql2",
	:host => "localhost",
	:user => "username",
	:pass => "password",
	:db => "database_name",
	:return_keys => "symbols",
	:encoding => "utf8",
	:threadsafe => true
}

begin
	options = {
		:verbose => false,
		:debug => false,
		:autorestart => false
	}
	OptionParser.new do |opts|
		opts.banner = "Usage: knjappserver.rb [options]"
		
		opts.on("-n", "--notice", "Run verbosely.") do |v|
			print "Running verbosely.\n"
			options[:verbose] = true
		end
		
		opts.on("-r", "--autorestart", "Autorestart the server when a file is changed. This is handy if using the appserver as a development server.") do |autorestart|
			options[:autorestart] = autorestart
		end
		
		opts.on("-d", "--debug", "Run in debugging mode.") do |debug|
			print "Entering debugging mode.\n"
			options[:debug] = true
		end
	end.parse!
rescue OptionParser::InvalidOption => e
	print "#{e.message}\n"
	exit
end

$knjappserver[:knjappserver] = Knjappserver.new(
	:debug => options[:debug],
	:autorestart => options[:autorestart],
	:verbose => options[:verbose],
	:title => "Site name",
	:port => 13081,
	:host => "0.0.0.0",
	:default_page => "index.rhtml",
	:doc_root => "[path to rhtml files]",
	:hostname => false,
	:default_filetype => "text/html",
	:error_report_emails => ["admin_email"],
	:error_report_from => "robot_email",
	:locales_root => "[path to locale files]",
	:max_requests_working => 5,
	:filetypes => {
    :jpeg => "image/jpeg",
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
		:file_ext => "rhtml",
		:callback => erbhandler.method(:erb_handler)
	],
	:db => Knj::Db.new(
		:type => "mysql",
		:subtype => "mysql2",
		:host => "localhost",
		:user => "knjappserver",
		:pass => "password",
		:db => "knjappserver",
		:return_keys => "symbols",
		:encoding => "utf8",
		:threadsafe => true
	),
	:smtp_args => {
		"smtp_host" => "smtp.server.com",
		"smtp_port" => 465,
		"smtp_user" => "robot@server.com",
		"smtp_passwd" => "password",
		"ssl" => true
	},
	:httpsession_db_args => dbargs
)

if $knjappserver[:knjappserver].config[:autorestart]
	#Also check config-file for changes.
	$knjappserver[:knjappserver].mod_event.args[:paths] << rpath
end

if ARGV[0] == "update_db"
	print "Running DB update script.\n"
	$knjappserver[:knjappserver].update_db
	exit
end

Dir.chdir($knjappserver[:knjappserver].config[:doc_root])
$knjappserver[:knjappserver].start