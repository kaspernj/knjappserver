class Knjappserver::CustomIO < StringIO
	def print(str)
		str = str.to_s
		appsrv = Thread.current[:knjappserver]
		
    if appsrv and cgroup = appsrv[:contentgroup] and httpsession = appsrv[:httpsession]
      httpsession.add_size(str.size)
      cgroup.write(str)
		else
			STDOUT.print(str) if !STDOUT.closed?
		end
	end
	
	alias << print
	alias write print
	alias p print
	alias puts print
end