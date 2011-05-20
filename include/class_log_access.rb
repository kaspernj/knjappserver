class Knjappserver::Log_access < Knj::Datarow
	def self.list(d)
		sql = "SELECT * FROM #{table} WHERE 1=1"
		
		ret = list_helper(d)
		d.args.each do |key, val|
			raise "Invalid key: #{key}."
		end
		
		sql += ret[:sql_where]
		sql += ret[:sql_order]
		sql += ret[:sql_limit]
		
		return d.ob.list_bysql(:Log_access, sql)
	end
	
	def get
		return ob.args[:knjappserver].log_data_hash("get")
	end
	
	def post
		return data_hash("post")
	end
	
	def meta
		return data_hash("meta")
	end
	
	def cookie
		return data_hash("cookie")
	end
	
	def ips
		return data_array(self[:ip_data_id])
	end
	
	def data_array(data_id)
		sql = "
			SELECT
				value_value.value AS value
			
			FROM
				Log_data_link AS value_links,
				Log_data_value AS value_value
			
			WHERE
				value_links.data_id = '#{data_id}' AND
				value_value.id = value_links.value_id
			
			ORDER BY
				key_links.no
		"
		
		arr = []
		q_array = db.query(sql)
		while d_array = q_array.fetch
			arr << d_array[:value]
		end
		
		return arr
	end
end