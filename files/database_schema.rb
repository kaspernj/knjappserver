$tables = {
	"tables" => {
		"sessions" => {
			"columns" => [
				{"name" => "id", "type" => "int", "autoincr" => true, "primarykey" => true},
				{"name" => "idhash", "type" => "varchar"},
				{"name" => "sess_data", "type" => "text"},
				{"name" => "date_added", "type" => "datetime"},
				{"name" => "ip", "type" => "varchar", "maxlength" => 15}
			],
			"indexes" => [
				{"name" => "date_added", "columns" => ["date_added"]},
				{"name" => "idhash", "columns" => ["idhash"]}
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
			],
			"indexes" => [
				{"name" => "lookup", "columns" => ["object_class", "object_id", "key", "locale"]}
			],
			"indexes_remove" => {
				"object_class" => true
			}
		}
	}
}