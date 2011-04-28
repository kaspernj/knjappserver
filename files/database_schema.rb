$tables = {
	"tables" => {
		"sessions" => {
			"columns" => [
				{"name" => "id", "type" => "int", "autoincr" => true, "primarykey" => true},
				{"name" => "idhash", "type" => "varchar"},
				{"name" => "sess_data", "type" => "text"}
			]
		},
		"translations" => {
			"columns" => [
				{"name" => "id", "type" => "int", "autoincr" => true, "primarykey" => true},
				{"name" => "object_class", "type" => "varchar", "maxlength" => 50},
				{"name" => "object_id", "type" => "int"},
				{"name" => "key", "type" => "varchar", "maxlength" => 50},
				{"name" => "locale", "type" => "varchar", "maxlength" => 5},
				{"name" => "value", "type" => "text"}
			]
		}
	}
}