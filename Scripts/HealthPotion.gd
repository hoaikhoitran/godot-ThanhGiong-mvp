extends Area2D

@export var heal_amount: int = 25

var _collected: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _collected:
		return
	if not body.is_in_group("level2_player"):
		return

	_collected = true
	if body.has_method("heal"):
		body.call("heal", heal_amount)

	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	queue_free()
