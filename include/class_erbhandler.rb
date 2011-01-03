require "#{$knjfwpath}knj/erb/include"

class Knjappserver::ERBHandler
	def erb_handler(data)
		$knj_eruby = KnjEruby
		
		#Hack the Knj::Thread to accept data - this is how get, post and etc. are set.
		Thread.current.data[:knjappserver] = data
		Thread.current.data[:knjappserver][:db] = data[:httpsession].db
		
		cont = KnjEruby.load_return(data[:filepath], {
			:with_headers => false,
			:io => data[:httpsession].out,
			:custom_io => true
		})
		headers = KnjEruby.headers
		KnjEruby.reset_headers
		
		data[:httpsession].out.rewind
		cont = data[:httpsession].out.read
		
		headers_ret = {}
		headers.each do |header|
			headers_ret[header[0]] = [header[1]]
		end
		
		return {
			:content => cont,
			:headers => headers_ret
		}
	end
end

KnjEruby.connect("error") do |e|
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
			
			html += "<br />Post:<br /><pre>#{Php.print_r(_post, true)}</pre>"
			html += "<br />Get:<br /><pre>#{Php.print_r(_get, true)}</pre>"
			html += "<br />Server:<br /><pre>#{Php.print_r(_server, true).html}</pre>"
			
			mail = Knj::Mailobj.new(_kas.config[:smtp_args])
			mail.to = email
			mail.subject = sprintf("Error @ %s", _kas.config[:title])
			mail.html = html
			mail.from = _kas.config[:error_report_from]
			mail.send
		end
	end
end