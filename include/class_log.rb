class Knjappserver::Log < Knj::Datarow
	def self.list(d)
		if d.args["object_lookup"]
			join_log_links = true
		end
		
		sql = "SELECT #{table}.* FROM #{table}"
		
		if join_log_links
			sql += "
				LEFT JOIN Log_link ON
					Log_link.log_id = #{table}.id
			"
		end
		
		sql += " WHERE 1=1"
		
		ret = list_helper(d)
		d.args.each do |key, val|
			case key
				when "object_lookup"
					data_val = d.ob.get_by(:Log_data_value, {"value" => val.class.name})
					return [] if !data_val #if this data-value cannot be found, nothing has been logged for the object. So just return empty array here and skip the rest.
					
					sql += " AND Log_link.object_class_value_id = '#{d.db.esc(data_val.id)}'"
					sql += " AND Log_link.object_id = '#{d.db.esc(val.id)}'"
				else
					raise "Invalid key: #{key}."
				end
		end
		
		sql += ret[:sql_where]
		sql += ret[:sql_order]
		sql += ret[:sql_limit]
		
		return d.ob.list_bysql(:Log, sql)
	end
	
	def self.add(d)
		if !d.data.has_key?(:date_saved)
			d.data[:date_saved] = d.db.date_out(Knj::Datet.new)
		end
	end
	
	def text
		return ob.get(:Log_data_value, self[:text_value_id])[:value]
	end
	
	def get
		ob.args[:knjappserver].log_data_hash(self[:get_keys_data_id], self[:get_values_data_id])
	end
	
	def post
		ob.args[:knjappserver].log_data_hash(self[:post_keys_data_id], self[:post_values_data_id])
	end
end