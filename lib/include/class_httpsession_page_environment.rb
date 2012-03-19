#This class handels all the magic-methods in a different way - by defining them as methods on the binding for the .rhtml-pages.
class Knjappserver::Httpsession::Page_environment
  def initialize(args = {})
    @args = args
  end
  
  def get_binding
    return binding
  end
  
  def _buf
    return $stdout
  end
  
  def _cookie
    return @args[:httpsession].cookie
  end
  
  def _db
    return @args[:kas].db_handler
  end
  
  def _get
    return @args[:httpsession].get
  end
  
  def _kas
    return @args[:kas]
  end
  
  alias _requestdata _kas
  
  def _kas_vars
    return @args[:kas].vars
  end
  
  def _httpsession
    return @args[:httpsession]
  end
  
  def _httpsession_var
    return @args[:httpsession].httpsession_var
  end
  
  def _post
    return @args[:httpsession].post
  end
  
  def _meta
    return @args[:httpsession].meta
  end
  
  alias _server _meta
  
  def _session
    return @args[:httpsession].session.sess_data
  end
  
  def _session_hash
    return @args[:httpsession].session_hash
  end
  
  def _session_obj
    return @args[:httpsession].session
  end
end