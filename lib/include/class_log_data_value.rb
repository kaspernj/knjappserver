class Knjappserver::Log_data_value < Knj::Datarow
	def self.list(d)
		sql = "SELECT * FROM #{table} WHERE 1=1"
		
		ret = list_helper(d)
		d.args.each do |key, val|
			raise "Invalid key: #{key}."
		end
		
		sql += ret[:sql_where]
		sql += ret[:sql_order]
		sql += ret[:sql_limit]
		
		return d.ob.list_bysql(:Log_data_value, sql)
	end
	
	def self.force(d, value)
		value_obj = d.ob.get_by(:Log_data_value, {
			"value" => value.to_s
		})
		
		if !value_obj
			value_obj = d.ob.add(:Log_data_value, {"value" => value})
		end
		
		return value_obj
	end
	
	def self.force_id(d, value)
    value_obj = d.db.query("SELECT * FROM Log_data_value WHERE value = '#{d.db.esc(value)}' LIMIT 1").fetch
    return value_obj[:id].to_i if value_obj
    return d.db.insert(:Log_data_value, {:value => value}, {:return_id => true}).to_i
	end
end