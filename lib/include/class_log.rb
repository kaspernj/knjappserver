class Knjappserver::Log < Knj::Datarow
	def self.list(d)
		sql = "SELECT #{table}.* FROM #{table}"
		
		if d.args["object_lookup"]
      data_val = d.ob.get_by(:Log_data_value, {"value" => d.args["object_lookup"].class.name})
      return [] if !data_val #if this data-value cannot be found, nothing has been logged for the object. So just return empty array here and skip the rest.
      
			sql += "
				LEFT JOIN Log_link ON
					Log_link.log_id = #{table}.id AND
					Log_link.object_class_value_id = '#{d.db.esc(data_val.id)}' AND
					Log_link.object_id = '#{d.db.esc(d.args["object_lookup"].id)}'
			"
		end
		
		sql += " WHERE 1=1"
		
		ret = list_helper(d)
		d.args.each do |key, val|
			case key
				when "object_lookup"
          sql += " AND Log_link.id IS NOT NULL"
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
	
	def first_line
		lines = self.text.to_s.split("\n").first.to_s
	end
	
	def links(args = {})
		return ob.list(:Log_link, {"log" => self}.merge(args))
	end
	
	def objects_html(ob_use)
		html = ""
		first = true
		
		self.links.each do |link|
			obj = link.object(ob_use)
			
			html += ", " if !first
			first = false if first
			
			if obj.respond_to?(:html)
				html += obj.html
			else
				html += "#{obj.class.name}{#{obj.id}}"
			end
		end
		
		return html
	end
end