class Knjappserver
  def session_fromid(args)
    ip = args[:ip].to_s
    idhash = args[:idhash].to_s
    ip = "bot" if idhash == "bot"
    
    @sessions = {} if !@sessions.key?(ip)
    
    if !@sessions.key?(idhash)
      session = @ob.get_by(:Session, {"idhash" => idhash})
      if !session
        session = @ob.add(:Session, {
          :idhash => idhash,
          :user_agent => args[:meta]["HTTP_USER_AGENT"],
          :ip => ip
        })
      end
      
      @sessions[idhash] = {
        :dbobj => session,
        :hash => {}
      }
    else
      session = @sessions[idhash][:dbobj]
    end
    
=begin
    if ip != "bot"
      if session[:user_agent] != args[:meta]["HTTP_USER_AGENT"]
        STDOUT.print "Invalid user-agent!\n"
        STDOUT.print Knj::Php.print_r(session, true)
        
        raise Knj::Errors::InvalidData, "Invalid user-agent."
      elsif !session.remember? and ip.to_s != session[:ip].to_s
        STDOUT.print "Invalid IP!\n"
        STDOUT.print Knj::Php.print_r(session, true)
        
        raise Knj::Errors::InvalidData, "Invalid IP."
      end
    end
=end
    
    @sessions[idhash][:time_lastused] = Time.now
    return @sessions[idhash]
  end
  
  def session_generate_id(args)
    meta = args[:meta]
    return Digest::MD5.hexdigest("#{Time.now.to_f}_#{meta["HTTP_HOST"]}_#{meta["REMOTE_HOST"]}_#{meta["HTTP_X_FORWARDED_SERVER"]}_#{meta["HTTP_X_FORWARDED_FOR"]}_#{meta["HTTP_X_FORWARDED_HOST"]}_#{meta["REMOTE_ADDR"]}_#{meta["HTTP_USER_AGENT"]}")
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
  
  def sessions_flush
    if @sessions
      @sessions.each do |session_hash, session_data|
        STDOUT.print "Flushing session: #{session_data[:dbobj].id}\n" if @debug
        session_data[:dbobj].flush
      end
    end
  end
end