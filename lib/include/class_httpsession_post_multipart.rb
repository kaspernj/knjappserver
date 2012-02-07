#This class parses and handels post-multipart requests.
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
        self.finish_data if @data
        
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
  
  #Add the current treated data to the return-hash.
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

#This is the actual returned object for fileuploads. It is able to do various user-friendly things like save the content to a given path, return the filename, returns the content to a string and more.
class Knjappserver::Httpsession::Post_multipart::File_upload
  def initialize(args)
    @args = args
  end
  
  #Returns the filename given for the fileupload.
  def filename
    return @args["fname"]
  end
  
  #Returns the size of the fileupload.
  def length
    return @args["data"].length
  end
  
  #Returns the headers given for the fileupload. Type and more should be here.
  def headers
    return @args["headers"]
  end
  
  #Returns the content of the file-upload as a string.
  def to_s
    return @args["data"]
  end
  
  #Saves the content of the fileupload to a given path.
  def save_to(filepath)
    File.open(filepath, "w") do |fp|
      fp.write(self.to_s)
    end
  end
end