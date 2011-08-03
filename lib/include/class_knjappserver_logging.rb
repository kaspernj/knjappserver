class Knjappserver
	def initialize_logging
		@logs_access_pending = []
		@logs_mutex = Mutex.new
		
		if @config[:logging] and @config[:logging][:access_db]
			self.timeout(:time => 30) do
				if @logs_access_pending.length > 0
					flush_access_log
				end
			end
		end
	end
	
	def flush_access_log
		@logs_mutex.synchronize do
			ins_arr = @logs_access_pending
			@logs_access_pending = []
			inserts = []
			inserts_links = []
			
			ins_arr.each do |ins|
				gothrough = [{
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
				}]
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
					
					data_id = @ob.static(:Log_data, :by_id_hash, hash)
					if !data_id
						data_id = @db.insert(:Log_data, {"id_hash" => hash}, {:return_id => true})
						
						link_count = 0
						data[:hash].keys.sort.each do |key|
							if data[:type] == :keys
								ins_data = "#{key.to_s}"
							else
								ins_data = "#{data[:hash][key]}"
							end
							
							ins_data = ins_data.force_encoding("UTF-8") if ins_data.respond_to?(:force_encoding)
							data_value_id = @ob.static(:Log_data_value, :force_id, ins_data)
							inserts_links << {:no => link_count, :data_id => data_id, :value_id => data_value_id}
							link_count += 1
						end
					end
					
					ins_hash[data[:col]] = data_id
				end
				
				hash = Knj::ArrayExt.array_hash(ins[:ips])
				data_id = @ob.static(:Log_data, :by_id_hash, hash)
				
				if !data_id
					data_id = @db.insert(:Log_data, {"id_hash" => hash}, {:return_id => true})
					
					link_count = 0
					ins[:ips].each do |ip|
            data_value_id = @ob.static(:Log_data_value, :force_id, ip)
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
						ins_data = "#{key.to_s}"
					else
						ins_data = "#{hash_obj[key].to_s}"
					end
					
					ins_data = ins_data.force_encoding("UTF-8") if ins_data.respond_to?(:force_encoding)
					data_value_id = @ob.static(:Log_data_value, :force_id, ins_data)
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
		@logs_mutex.synchronize do
			objs = [objs] if !objs.is_a?(Array)
			log_value_id = @ob.static(:Log_data_value, :force_id, msg)
			ins_data = {
				:date_saved => Time.new,
				:text_value_id => log_value_id
			}
			
			get_hash = log_hash_ins(_get) if _get
			if get_hash
				ins_data[:get_keys_data_id] = get_hash[:keys_data_id]
				ins_data[:get_values_data_id] = get_hash[:values_data_id]
			end
			
			post_hash = log_hash_ins(_post) if _post
			if post_hash
				ins_data[:post_keys_data_id] = post_hash[:keys_data_id]
				ins_data[:post_values_data_id] = post_hash[:values_data_id]
			end
			
			log_id = @db.insert(:Log, ins_data, {:return_id => true})
			
			log_links = []
			objs.each do |obj|
        class_data_id = @ob.static(:Log_data_value, :force_id, obj.class.name)
        
        log_links << {
          :object_class_value_id => class_data_id,
          :object_id => obj.id,
          :log_id => log_id
        }
			end
			
			@db.insert_multi(:Log_link, log_links)
		end
	end
	
	def logs_table(obj, args = {})
		links = @ob.list(:Log_link, {"object_class" => obj.class.name, "object_id" => obj.id, "limit" => 500, "orderby" => [["id", "desc"]]})
		
		html = "<table class=\"list knjappserver_log_table\">"
		html += "<thead>"
		html += "<tr>"
		html += "<th>ID</th>"
		html += "<th>Message</th>"
		html += "<th>Date &amp; time</th>"
		html += "<th>Objects</th>" if args[:ob_use]
		html += "</tr>"
		html += "</thead>"
		html += "<tbody>"
		
		links.each do |link|
      log = link.log
      
			msg_lines = log.text.split("\n")
			first_line = msg_lines[0].to_s
			
			classes = ["knjappserver_log", "knjappserver_log_#{log.id}"]
			classes << "knjappserver_log_multiple_lines" if msg_lines.length > 1
			
			html += "<tr class=\"#{classes.join(" ")}\">"
			html += "<td>#{log.id}</td>"
			html += "<td>#{first_line.html}</td>"
			html += "<td>#{log.date_saved_str}</td>"
			html += "<td>#{log.objects_html(args[:ob_use])}</td>" if args[:ob_use]
			html += "</tr>"
		end
		
		if links.empty?
			html += "<tr>"
			html += "<td colspan=\"2\" class=\"error\">No logs were found for that object.</td>"
			html += "</tr>"
		end
		
		html += "</tbody>"
		html += "</table>"
		
		return html
	end
end