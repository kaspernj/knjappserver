class Knjappserver
  def trans(obj, key)
    args = {}
    args[:locale] = _session[:locale] if _session[:locale] and !args[:locale]
    args[:locale] = _httpsession.data[:locale] if _httpsession.data[:locale] and !args[:locale]
    @translations.get(obj, key, args)
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