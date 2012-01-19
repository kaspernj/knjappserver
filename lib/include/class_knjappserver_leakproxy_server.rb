#This class starts a Knjappserver in another process. This process can be used for scripts that leak memory. The memoy-usage is
#looked over and the process restarted when it reaches a certain point. Doing the restart all waiting requests will wait gracefully.
class Knjappserver::Leakproxy_server
  def initialize(args)
    require "#{$knjpath}/process"
    
    leakproxy_path = "#{File.dirname(__FILE__)}/../scripts/leakproxy.rb"
    executable = Knj::Os.executed_executable
    
    @stdin, @stdout, @stderr, @wait_thr = Open3.popen3(executable, leakproxy_path, "r+")
    @kas = args[:kas]
    @config = @kas.config
    
    Thread.new do
      STDOUT.print "Doing loop:\n"
      @stderr.each_line do |str|
        STDOUT.print "Test: #{str}"
      end
    end
    
    pass_conf = {}
    pass_conf_keys = [:knjrbfw_path]
    pass_conf_keys.each do |key, val|
      pass_conf[key] = val if @config.key?(key)
    end
    
    args_pass = {
      :config => pass_conf
    }
    
    @stdin.write("#{Marshal.dump(args_pass)}\n")
    
    @process = Knj::Process.new(
      :out => @stdin,
      :in => @stdout,
      :err => @stderr,
      :listen => true,
      :debug => true,
      :on_rec => proc{|d|
        obj = d.obj
        
        if obj.is_a?(Hash)
          if obj["type"] == "print"
            STDOUT.print obj["str"]
          end
        else
          STDOUT.print Knj::Php.print_r(obj, true)
        end
      }
    )
  end
  
  def spawn
    
  end
end