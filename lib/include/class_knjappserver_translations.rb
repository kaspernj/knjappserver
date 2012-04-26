class Knjappserver
  def trans(obj, key, args = {})
    args[:locale] = self.trans_locale if !args[:locale]
    trans_val = @translations.get(obj, key, args).to_s
    
    if trans_val.length <= 0
      trans_val = @events.call(:trans_no_str, {:obj => obj, :key => key, :args => args})
    end
    
    return trans_val
  end
  
  def trans_locale(args = {})
    if args.is_a?(Hash) and args[:locale]
      return args[:locale]
    elsif _session and _session[:locale]
      return _session[:locale]
    elsif _httpsession and _httpsession.data[:locale]
      return _httpsession.data[:locale]
    elsif Thread.current[:locale]
      return Thread.current[:locale]
    elsif @config[:locale_default]
      return @config[:locale_default]
    end
    
    raise "Could not figure out locale."
  end
  
  def trans_set(obj, values, args = {})
    args[:locale] = self.trans_locale if !args[:locale]
    @translations.set(obj, values, args)
  end
  
  def trans_del(obj)
    @translations.delete(obj)
  end
end