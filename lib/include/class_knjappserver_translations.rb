class Knjappserver
  def trans(obj, key, args = {})
    if !args.key?(:locale)
      if _session[:locale]
        args[:locale] = _session[:locale]
      elsif _httpsession.data[:locale]
        args[:locale] = _httpsession.data[:locale]
      end
    end
    
    trans_val = @translations.get(obj, key, args).to_s
    
    if trans_val.length <= 0
      trans_val = @events.call(:trans_no_str, {:obj => obj, :key => key, :args => args})
    end
    
    return trans_val
  end
  
  def trans_set(obj, values)
    args = {}
    args[:locale] = _session[:locale] if _session[:locale] and !args[:locale]
    args[:locale] = _httpsession.data[:locale] if _httpsession.data[:locale] and !args[:locale]
    @translations.set(obj, values, args)
  end
  
  def trans_del(obj)
    @translations.delete(obj)
  end
end