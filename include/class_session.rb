class Knjappserver::Session < Db_row
	attr_reader :kas, :accessor, :edata
	
	def initialize(data, kas)
		@kas = kas
		@edata = {}
		super(:objects => @kas.ob, :db => @kas.db, :data => data, :table => :sessions, :force_selfdb => true)
		
		if self[:sess_data].length > 0
			begin
				@sess_data = Marshal.load(self[:sess_data])
			rescue ArgumentError
				@sess_data = {}
			end
		else
			@sess_data = {}
		end
		
		@accessor = Knjappserver::Session_accessor.new(self)
	end
	
	def self.list(args = {}, kas = nil)
		sql = "SELECT * FROM sessions WHERE 1=1"
		
		args.each do |key, val|
			case key
				when :idhash
					sql += " AND #{key} = '#{val.sql}'"
				else
					raise "Invalid key: #{key}."
			end
		end
		
		return kas.ob.list_bysql(:Session, sql)
	end
	
	def self.add(kas, data)
		kas.db.insert(:sessions, data)
		return kas.ob.get(:Session, kas.db.last_id)
	end
	
	def delete
		@kas.db.delete(:sessions, {:id => self.id})
	end
	
	def sess_data
		return @sess_data
	end
	
	def sess_data=(newdata)
		m_newdata = Marshal.dump(newdata)
		self[:sess_data] = m_newdata
		@sess_data = newdata
	end
end