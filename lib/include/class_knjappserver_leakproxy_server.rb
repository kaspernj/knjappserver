#This class starts a Knjappserver in another process. This process can be used for scripts that leak memory. The memoy-usage is
#looked over and the process restarted when it reaches a certain point. Doing the restart all waiting requests will wait gracefully.
class Knjappserver::Leakproxy_server
  def initialize(args = {})
    
  end
end