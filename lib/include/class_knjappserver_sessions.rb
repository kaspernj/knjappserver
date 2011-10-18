class Knjappserver
  def session_fromid(args)
    ip = args[:ip].to_s
    idhash = args[:idhash].to_s
    ip = "bot" if idhash == "bot"
    
    @sessions[ip] = {} if !@sessions.has_key?(ip)
    
    if !@sessions[ip].has_key?(idhash)
      session = @ob.get_by(:Session, {"idhash" => args[:idhash]})
      if !session
        session = @ob.add(:Session, {
          :idhash => idhash,
          :user_agent => args[:meta]["HTTP_USER_AGENT"],
          :ip => ip
        })
      end
      
      @sessions[ip][idhash] = {
        :dbobj => session,
        :hash => {}
      }
    else
      session = @sessions[ip][idhash][:dbobj]
    end
    
    if ip != "bot"
      if session[:user_agent] != args[:meta]["HTTP_USER_AGENT"]
        STDOUT.print "Session user-agent: #{session[:user_agent]}\n"
        STDOUT.print "Meta user-agent: #{args[:meta]["HTTP_USER_AGENT"]}\n"
        
        raise Knj::Errors::InvalidData, "Invalid user-agent."
      elsif !session.remember? and ip.to_s != session[:ip].to_s
        raise Knj::Errors::InvalidData, "Invalid IP."
      end
    end
    
    @sessions[ip][idhash][:time_lastused] = Time.now
    return @sessions[ip][idhash]
  end
  
  def session_generate_id(args)
    meta = args[:meta]
    @session_id = Digest::MD5.hexdigest("#{Time.now.to_f}_#{meta["HTTP_HOST"]}_#{meta["REMOTE_HOST"]}_#{meta["HTTP_X_FORWARDED_SERVER"]}_#{meta["HTTP_X_FORWARDED_FOR"]}_#{meta["HTTP_X_FORWARDED_HOST"]}_#{meta["REMOTE_ADDR"]}_#{meta["HTTP_USER_AGENT"]}")
  end
  
  def session_remember
    session = _httpsession.session
    session[:remember] = 1
    
    self.cookie(
      "name" => "KnjappserverSession",
      "value" => _httpsession.session_id,
      "path" => "/",
      "expires" => Time.now + 32140800 #add around 12 months
    )
  end
end