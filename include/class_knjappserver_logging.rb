class Knjappserver
	def flush_access_log
		ins_arr = @logs_access_pending
		@logs_access_pending = []
		inserts = []
		inserts_links = []
		
		data_cache = {}
		q_data = @db.query("SELECT id, id_hash FROM Log_data")
		while d_data = q_data.fetch
			data_cache[d_data[:id_hash]] = d_data[:id]
		end
		
		ins_arr.each do |ins|
			gothrough = [
				{
					:col => :get_keys_data_id,
					:hash => ins[:get],
					:type => :keys
				},{
					:col => :get_values_data_id,
					:hash => ins[:get],
					:type => :values
				},{
					:col => :post_keys_data_id,
					:hash => ins[:post],
					:type => :keys
				},{
					:col => :post_values_data_id,
					:hash => ins[:post],
					:type => :values
				},{
					:col => :cookie_keys_data_id,
					:hash => ins[:cookie],
					:type => :keys
				},{
					:col => :cookie_values_data_id,
					:hash => ins[:cookie],
					:type => :values
				},{
					:col => :meta_keys_data_id,
					:hash => ins[:meta],
					:type => :keys
				},{
					:col => :meta_values_data_id,
					:hash => ins[:meta],
					:type => :values
				}
			]
			ins_hash = {
				:session_id => ins[:session_id],
				:date_request => ins[:date_request]
			}
			
			gothrough.each do |data|
				if data[:type] == :keys
					hash = Knj::ArrayExt.hash_keys_hash(data[:hash])
				else
					hash = Knj::ArrayExt.hash_values_hash(data[:hash])
				end
				
				data_id = data_cache[hash]
				if !data_id
					data_id = @db.insert(:Log_data, {"id_hash" => hash}, {:return_id => true})
					data_cache[hash] = data_id
					
					link_count = 0
					data[:hash].keys.sort.each do |key|
						if data[:type] == :keys
							ins_data = key
						else
							ins_data = data[:hash][key]
						end
						
						data_value = @db.single(:Log_data_value, {"value" => ins_data})
						if data_value
							data_value_id = data_value[:id]
						else
							data_value_id = @db.insert(:Log_data_value, {"value" => ins_data}, {:return_id => true})
						end
						
						inserts_links << {:no => link_count, :data_id => data_id, :value_id => data_value_id}
						link_count += 1
					end
				end
				
				ins_hash[data[:col]] = data_id
			end
			
			hash = Knj::ArrayExt.array_hash(ins[:ips])
			data_id = data_cache[hash]
			
			if !data_id
				data_id = @db.insert(:Log_data, {"id_hash" => hash}, {:return_id => true})
				data_cache[hash] = data_id
				
				link_count = 0
				ins[:ips].each do |ip|
					data_value = @db.single(:Log_data_value, {"value" => ip})
					
					if data_value
						data_value_id = data_value[:id]
					else
						data_value_id = @db.insert(:Log_data_value, {"value" => ip}, {:return_id => true})
					end
					
					inserts_links << {:no => link_count, :data_id => data_id, :value_id => data_value_id}
					link_count += 1
				end
			end
			
			ins_hash[:ip_data_id] = data_id
			inserts << ins_hash
		end
		
		@db.insert_multi(:Log_access, inserts)
		@db.insert_multi(:Log_data_link, inserts_links)
		@ob.unset_class([:Log_access, :Log_data, :Log_data_link, :Log_data_value])
	end
	
	def log_hash_ins(hash_obj)
		inserts_links = []
		ret = {}
		[:keys, :values].each do |type|
			if type == :keys
				hash = Knj::ArrayExt.hash_keys_hash(hash_obj)
			else
				hash = Knj::ArrayExt.hash_values_hash(hash_obj)
			end
			
			data_id = @db.single(:Log_data, {"id_hash" => hash})
			data_id = data_id[:id] if data_id
			
			if !data_id
				data_id = @db.insert(:Log_data, {"id_hash" => hash}, {:return_id => true})
				
				link_count = 0
				hash_obj.keys.sort.each do |key|
					if type == :keys
						ins_data = key
					else
						ins_data = hash_obj[key]
					end
					
					data_value = @db.single(:Log_data_value, {"value" => ins_data})
					if data_value
						data_value_id = data_value[:id]
					else
						data_value_id = @db.insert(:Log_data_value, {"value" => ins_data}, {:return_id => true})
					end
					
					inserts_links << {:no => link_count, :data_id => data_id, :value_id => data_value_id}
					link_count += 1
				end
			end
			
			if type == :keys
				ret[:keys_data_id] = data_id
			else
				ret[:values_data_id] = data_id
			end
		end
		
		@db.insert_multi(:Log_data_link, inserts_links)
		
		return ret
	end
	
	def log_data_hash(keys_id, values_id)
		keys_data_obj = @ob.get(:Log_data, keys_id)
		values_data_obj = @ob.get(:Log_data, values_id)
		
		sql = "
			SELECT
				key_value.value AS `key`,
				value_value.value AS value
			
			FROM
				Log_data_link AS key_links,
				Log_data_link AS value_links,
				Log_data_value AS key_value,
				Log_data_value AS value_value
			
			WHERE
				key_links.data_id = '#{keys_id}' AND
				value_links.data_id = '#{values_id}' AND
				key_links.no = value_links.no AND
				key_value.id = key_links.value_id AND
				value_value.id = value_links.value_id
			
			ORDER BY
				key_links.no
		"
		
		hash = {}
		q_hash = db.query(sql)
		while d_hash = q_hash.fetch
			hash[d_hash[:key].to_sym] = d_hash[:value]
		end
		
		return hash
	end
	
	def log(msg, objs)
		objs = [objs] if !objs.is_a?(Array)
		
		get_hash = log_hash_ins(_get)
		post_hash = log_hash_ins(_post)
		
		log_value = @ob.static(:Log_data_value, :force, msg)
		log_obj = @ob.add(:Log, {
			:text_value_id => log_value.id,
			:get_keys_data_id => get_hash[:keys_data_id],
			:get_values_data_id => get_hash[:values_data_id],
			:post_keys_data_id => post_hash[:keys_data_id],
			:post_values_data_id => post_hash[:values_data_id]
		})
		
		objs.each do |obj|
			log_link_obj = @ob.add(:Log_link, {
				:object => obj,
				:log_id => log_obj.id
			})
		end
	end
end