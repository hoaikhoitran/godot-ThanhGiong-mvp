extends Enemy


func _ready() -> void:
	max_health = 60
	damage_to_player = 10
	is_boss = true
	super._ready()
	add_to_group(&"level2_boss")
