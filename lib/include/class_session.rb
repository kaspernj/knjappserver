class Knjappserver::Session < Knj::Datarow
	attr_reader :edata
	attr_accessor :sess_data
	
	def initialize(d)
		@edata = {}
		super(d)
		
		if self[:sess_data].to_s.length > 0
			begin
				@sess_data = Marshal.load(Base64.decode64(self[:sess_data]))
			rescue ArgumentError
				@sess_data = {}
			end
		else
			@sess_data = {}
		end
	end
	
	def self.list(d)
		sql = "SELECT * FROM #{table} WHERE 1=1"
		
		ret = list_helper(d)
		d.args.each do |key, val|
			raise "Invalid key: #{key}."
		end
		
		sql += ret[:sql_where]
		sql += ret[:sql_order]
		sql += ret[:sql_limit]
		
		return d.ob.list_bysql(:Session, sql)
	end
	
	def self.add(d)
		d.data[:date_added] = Time.now if !d.data[:date_added]
		d.date[:date_lastused] = Time.now if !d.data[:date_lastused]
	end
	
	def flush
    self.update(
      :sess_data => Base64.encode64(Marshal.dump(@sess_data)),
      :date_lastused => Time.now
    )
	end
end