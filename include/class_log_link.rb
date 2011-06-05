class Knjappserver::Log_link < Knj::Datarow
	def self.list(d)
		sql = "SELECT * FROM #{table} WHERE 1=1"
		
		ret = list_helper(d)
		d.args.each do |key, val|
			raise "Invalid key: #{key}."
		end
		
		sql += ret[:sql_where]
		sql += ret[:sql_order]
		sql += ret[:sql_limit]
		
		return d.ob.list_bysql(:Log_link, sql)
	end
	
	def self.add(d)
		if d.data.has_key?(:object)
			class_data_id = d.ob.static(:Log_data_value, :force, d.data[:object].class.name)
			d.data[:object_class_value_id] = class_data_id.id
			d.data[:object_id] = d.data[:object].id
			d.data.delete(:object)
		end
		
		log = d.ob.get(:Log, d.data[:log_id]) #throws exception if it doesnt exist.
	end
	
	def object(ob_use)
		begin
			class_name = ob.get(:Log_data_value, self[:object_class_value_id])[:value].split("::").last
			return ob_use.get(class_name, self[:object_id])
		rescue Knj::Errors::NotFound
			return false
		end
	end
end