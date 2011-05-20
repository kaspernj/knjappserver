require "#{$knjappserver_config["knjrbfw"]}knj/erb/include.rb"

class Knjappserver::ERBHandler
	def erb_handler(data)
		#Hack the Knj::Thread to accept data - this is how get, post and etc. are set.
		Thread.current.data[:knjappserver] = data
		
		eruby = data[:httpsession].eruby
		eruby.connect("error") do |e|
			if _kas.config[:error_report_emails]
				_kas.config[:error_report_emails].each do |email|
					html = "An error occurred." + "<br /><br />"
					html += "<b>#{e.class.name.html}: #{e.message.html}</b><br /><br />"
					
					#Lets hide all the stuff in what is not the users files to make it easier to debug.
					bt = e.backtrace
					to = bt.length - 9
					bt = bt[0..to]
					
					bt.reverse.each do |line|
						html += line.html + "<br />"
					end
					
					html += "<br />Post:<br /><pre>#{Knj::Php.print_r(_post, true)}</pre>"
					html += "<br />Get:<br /><pre>#{Knj::Php.print_r(_get, true)}</pre>"
					html += "<br />Server:<br /><pre>#{Knj::Php.print_r(_server, true).html}</pre>"
					
					mail = Knj::Mailobj.new(_kas.config[:smtp_args])
					mail.to = email
					mail.subject = sprintf("Error @ %s", _kas.config[:title])
					mail.html = html
					mail.from = _kas.config[:error_report_from]
					mail.send
				end
			end
		end
		
		cont = eruby.load_return(data[:filepath], {
			:with_headers => false,
			:io => data[:httpsession].out,
			:custom_io => true
		})
		headers = eruby.headers
		eruby.reset_headers
		
		data[:httpsession].out.rewind
		cont = data[:httpsession].out.read
		
		headers_ret = {}
		headers.each do |header|
			headers_ret[header[0]] = [header[1]]
		end
		
		Thread.current.data[:knjappserver].clear
		Thread.current.data.delete(:knjappserver)
		
		return {
			:content => cont,
			:headers => headers
		}
	end
end

#Hack to detect we are running KnjEruby
$knj_eruby = KnjEruby