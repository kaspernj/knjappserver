class Knjappserver::Httpsession::Post_multipart
  attr_reader :return
  
  def initialize(args)
    @args = args
    boundary_regexp = /\A--#{@args["boundary"]}(--)?#{@args["crlf"]}\z/
    @return = {}
    @data = nil
    @mode = nil
    @headers = {}
    
    @args["io"].each do |line|
      if boundary_regexp =~ line
        #Finish the data we were writing.
        if @data
          self.finish_data
        end
        
        @data = ""
        @mode = "headers"
      elsif @mode == "headers"
        if match = line.match(/^(.+?):\s+(.+)#{@args["crlf"]}$/)
          @headers[match[1].to_s.downcase] = match[2]
        elsif line == @args["crlf"]
          @mode = "body"
        else
          raise "Could not match header from: '#{line}'."
        end
      elsif @mode == "body"
        @data << line
      else
        raise "Invalid mode: '#{@mode}'."
      end
    end
    
    @data = nil
    @headers = nil
    @mode = nil
    @args = nil
  end
  
  def finish_data
    @data.chop!
    name = nil
    
    disp = @headers["content-disposition"]
    raise "No 'content-disposition' was given." if !disp
    
    match_name = disp.match(/name=\"(.+?)\"/)
    raise "Could not match name." if !match_name
    
    match_fname = disp.match(/filename=\"(.+?)\"/)
    
    if match_fname
      obj = Knjappserver::Httpsession::Post_multipart::File_upload.new(
        "fname" => match_fname[1],
        "headers" => @headers,
        "data" => @data
      )
      @return[match_name[1]] = obj
      @data = nil
      @headers = {}
      @mode = nil
    else
      @return[match_name[1]] = @data
      @data = nil
      @headers = {}
      @mode = nil
    end
  end
end

class Knjappserver::Httpsession::Post_multipart::File_upload
  def initialize(args)
    @args = args
  end
  
  #Returns the size of the upload.
  def size
    return @args["data"].length
  end
  
  def filename
    return @args["fname"]
  end
  
  def headers
    return @args["headers"]
  end
  
  def to_s
    return @args["data"]
  end
  
  def to_json(*args)
    raise "File_upload-objects should not be converted to json."
  end
end