class Knjappserver
  def initialize_cmdline
    @cmds = {}
    
    Knj::Thread.new do
      line = $stdin.gets
      next if line == "\n"
      
      called = 0
      @cmds.each do |key, connects|
        data = {}
        
        if key.is_a?(Regexp)
          if line.match(key)
            connects.each do |conn|
              called += 1
              conn[:block].call(data)
            end
          end
        else
          raise "Unknown class for 'cmd_connect': '#{key.class.name}'."
        end
      end
      
      if called == 0
        print "Unknown command: '#{line.strip}'.\n"
      end
    end
    
    self.cmd_connect(/^\s*restart\s*$/i) do |data|
      print "Restart will begin shortly.\n"
      self.should_restart = true
    end
    
    self.cmd_connect(/^\s*stop\s*$/i) do |data|
      self.stop
    end
  end
  
  #Connects a proc to a specific command in the command-line (key should be a regex).
  def cmd_connect(cmd, &block)
    @cmds[cmd] = [] if !@cmds.key?(cmd)
    @cmds[cmd] << {:block => block}
  end
end