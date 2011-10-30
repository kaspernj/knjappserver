#This class handels the adding of content and writing to socket. Since this can be done with multiple threads and multiple IO's it can get complicated.
class Knjappserver::Httpsession::Contentgroup
  attr_reader :done, :cur_data
  attr_accessor :chunked, :socket
  NL = "\r\n"
  
  def initialize(args = {})
    @block = args[:restart_proc]
    @socket = args[:socket]
    @chunked = args[:chunked]
    @mutex = Mutex.new
    @debug = false
  end
  
  def init
    @done = false
    @thread = nil
    @cur_data = {
      :str => "",
      :done => false
    }
    @ios = [@cur_data]
  end
  
  def reset
    @ios = []
    @done = false
    @thread = nil
    
    @mutex.synchronize do
      self.new_io
    end
  end
  
  def new_io(obj = "")
    @cur_data[:done] = true if @cur_data and @cur_data.key?(:done)
    @cur_data = {:str => obj, :done => false}
    @ios << @cur_data
  end
  
  def new_thread
    @mutex.synchronize do
      cgroup = Knjappserver::Httpsession::Contentgroup.new(:socket => @socket, :chunked => @chunked)
      cgroup.init
      
      data = {:cgroup => cgroup, :done => false}
      @ios << data
      self.new_io
      Thread.current[:knjappserver] = {} if !Thread.current[:knjappserver]
      Thread.current[:knjappserver][:contentgroup] = self
      
      return data
    end
  end
  
  def write(cont)
    @mutex.synchronize do
      @cur_data[:str] += cont.to_s
    end
    
    if @block and !@thread and @cur_data[:str].length > 512
      self.write_output
    end
  end
  
  def write_output
    if @block and !@thread
      @mutex.synchronize do
        @thread = Knj::Thread.new do
          @block.call
        end
      end
    end
  end
  
  def mark_done
    @mutex.synchronize do
      @cur_data[:done] = true
      @done = true
    end
  end
  
  def join
    @ios.each do |data|
      data[:cgroup].join if data.key?(:cgroup)
      data[:thread].join if data.key?(:thread)
    end
    
    if @block
      sleep 0.1 while !@thread
      @thread.join
    end
  end
  
  def write_to_socket
    @ios.each do |data|
      if data.key?(:cgroup)
        data[:cgroup].write_to_socket
      elsif data.key?(:str)
        if data[:str].is_a?(File)
          file = data[:str]
          
          loop do
            begin
              buf = file.sysread(4096)
            rescue EOFError
              break
            end
            
            if @chunked
              #STDOUT.print("#{buf.length.to_s(16)}#{NL}#{buf}#{NL}")
              @socket.write("#{buf.length.to_s(16)}#{NL}#{buf}#{NL}")
            else
              #STDOUT.print buf
              @socket.write(buf)
            end
          end
          
          file.close
        else
          loop do
            break if data[:str].size <= 0 and data[:done]
            sleep 0.1 while data[:str].size <= 512 and !data[:done]
            
            str = nil
            @mutex.synchronize do
              str = data[:str].bytes
              data[:str] = ""
            end
            
            str.each_slice(512) do |slice|
              buf = slice.pack("C*")
              next if buf.length <= 0
              
              if @chunked
                @socket.write("#{buf.length.to_s(16)}#{NL}#{buf}#{NL}")
              else
                @socket.write(buf)
              end
            end
          end
        end
      else
        raise "Unknown object: '#{data.class.name}'."
      end
    end
  end
end