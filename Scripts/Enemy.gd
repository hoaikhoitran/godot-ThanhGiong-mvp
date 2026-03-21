extends CharacterBody2D

@export var hp: int = 2
@export var move_speed: float = 110.0

var _home_position: Vector2
var _can_chase: bool = false

func _ready() -> void:
	# Groups used for counting and for PlayerAdult hit detection.
	_home_position = position
	add_to_group("enemies")
	add_to_group("enemy")


func set_can_chase(value: bool) -> void:
	_can_chase = value


func reset_to_home() -> void:
	# Ensures enemies don't get stuck clustered if Player wasn't ready yet.
	position = _home_position


func _physics_process(_delta: float) -> void:
	if not _can_chase:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var player := get_tree().get_first_node_in_group("level2_player") as Node2D
	if player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var dir: Vector2 = player.global_position - global_position
	if dir.length() > 0.01:
		velocity = dir.normalized() * move_speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()


func take_damage(amount: int = 1) -> void:
	hp -= max(1, amount)
	if hp > 0:
		return

	Global.enemy_defeated()
	queue_free()

