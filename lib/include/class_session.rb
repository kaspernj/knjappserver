class Knjappserver::Session < Knj::Datarow
	attr_reader :accessor, :edata
	
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
		
		@accessor = Knjappserver::Session_accessor.new(self)
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
		d.data[:date_added] = Knj::Datet.new.dbstr if !d.data[:date_added]
	end
	
	def sess_data
		return @sess_data
	end
	
	def sess_data=(newdata)
		m_newdata = Base64.encode64(Marshal.dump(newdata))
		self[:sess_data] = m_newdata
		@sess_data = newdata
	end
end