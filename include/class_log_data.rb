class Knjappserver::Log_data < Knj::Datarow
	def self.list(d)
		sql = "SELECT * FROM #{table} WHERE 1=1"
		
		ret = list_helper(d)
		d.args.each do |key, val|
			raise "Invalid key: #{key}."
		end
		
		sql += ret[:sql_where]
		sql += ret[:sql_order]
		sql += ret[:sql_limit]
		
		return d.ob.list_bysql(:Log_data, sql)
	end
	
	def self.force(d, id_hash)
		data_obj = d.ob.get_by(:Log_data, {"id_hash" => id_hash})
		
		if !data_obj
			data_obj = d.ob.add(:Log_data, {"id_hash" => id_hash})
		end
		
		return data_obj
	end
	
	def links(args = {})
		return ob.list(:Log_data_link, {"data" => self}.merge(args))
	end
end