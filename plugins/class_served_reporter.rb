Knj::Thread.new do
	last_requests = 0
	
	loop do
		sleep 1
		
		if !$knjappserver[:knjappserver]
			next
		end
		
		cur_requests = $knjappserver[:knjappserver].served
		served = cur_requests - last_requests
		
		STDOUT.print "Last: #{last_requests}\n"
		STDOUT.print "Cur: #{cur_requests}\n"
		STDOUT.print "Served: #{served}\n"
		STDOUT.print "\n"
		
		last_requests = cur_requests
		STDOUT.print "Served #{served} / sec\n"
	end
end