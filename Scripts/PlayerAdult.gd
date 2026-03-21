extends CharacterBody2D

@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var sprite: Sprite2D = $Sprite2D
@onready var camera: Camera2D = $Camera2D

@export var move_speed: float = 220.0
@export var attack_cooldown: float = 0.4
@export var attack_duration: float = 0.15
@export var attack_range_distance: float = 18.0

var _next_attack_time: float = 0.0
var is_attacking: bool = false
var _last_facing: Vector2 = Vector2.RIGHT

var _idle_modulate: Color = Color(1, 1, 1, 1)
var _attack_modulate: Color = Color(1, 0.75, 0.6, 1)

# Prevents damaging the same enemy multiple times during one attack swing.
var _hit_enemies: Dictionary = {}

var _play_bounds: Rect2 = Rect2()

func _clamp_to_play_bounds() -> void:
	var gp := global_position
	var x_margin := 8.0
	var y_margin := 8.0
	var coll := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if coll != null and coll.shape != null:
		if coll.shape is RectangleShape2D:
			var r := coll.shape as RectangleShape2D
			x_margin = abs(r.extents.x) * coll.scale.x
			y_margin = abs(r.extents.y) * coll.scale.y
		elif coll.shape is CircleShape2D:
			var c := coll.shape as CircleShape2D
			x_margin = c.radius * coll.scale.x
			y_margin = c.radius * coll.scale.y

	var r := _play_bounds
	gp.x = clamp(gp.x, r.position.x + x_margin, r.end.x - x_margin)
	gp.y = clamp(gp.y, r.position.y + y_margin, r.end.y - y_margin)
	global_position = gp


func _ready() -> void:
	add_to_group("level2_player")
	attack_hitbox.monitoring = false
	attack_hitbox.body_entered.connect(_on_attack_body_entered)

	_play_bounds = get_viewport().get_visible_rect()
	var lr := get_parent()
	if lr != null and lr.has_meta("level2_map_bounds"):
		_play_bounds = lr.get_meta("level2_map_bounds") as Rect2

	if camera != null:
		var b := _play_bounds
		camera.limit_left = int(floor(b.position.x))
		camera.limit_top = int(floor(b.position.y))
		camera.limit_right = int(ceil(b.end.x))
		camera.limit_bottom = int(ceil(b.end.y))
		camera.make_current()

	# Force visibility/priority so Level_2 always shows the adult player sprite.
	sprite.visible = true
	sprite.modulate = _idle_modulate
	sprite.z_index = 10
	sprite.scale = Vector2(0.8, 0.8)


func _physics_process(_delta: float) -> void:
	var dir := _get_move_vector()

	if dir.length() > 1.0:
		dir = dir.normalized()

	if dir != Vector2.ZERO:
		_last_facing = _direction_to_cardinal(dir)

	if not Global.player_can_move:
		velocity = Vector2.ZERO
		move_and_slide()
		_clamp_to_play_bounds()
		return

	velocity = dir * move_speed
	move_and_slide()
	_clamp_to_play_bounds()

	var now := Time.get_ticks_msec() / 1000.0
	if not is_attacking \
		and Input.is_action_just_pressed("attack") \
		and now >= _next_attack_time:
		_start_attack(now)


func _get_move_vector() -> Vector2:
	if InputMap.has_action("move_left") and InputMap.has_action("move_right") \
			and InputMap.has_action("move_up") and InputMap.has_action("move_down"):
		return Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var x := Input.get_axis("ui_left", "ui_right")
	var y := Input.get_axis("ui_up", "ui_down")
	var v := Vector2(x, y)
	return v


func _direction_to_cardinal(dir: Vector2) -> Vector2:
	# Convert analog input to 4 directions for simple hitbox placement.
	if abs(dir.x) >= abs(dir.y):
		return Vector2.RIGHT if dir.x >= 0.0 else Vector2.LEFT
	return Vector2.DOWN if dir.y >= 0.0 else Vector2.UP


func _start_attack(now: float) -> void:
	is_attacking = true
	_hit_enemies.clear()

	var facing := _last_facing
	attack_hitbox.position = facing * attack_range_distance

	attack_hitbox.monitoring = true
	attack_hitbox.monitorable = true
	sprite.modulate = _attack_modulate
	await get_tree().create_timer(attack_duration).timeout
	attack_hitbox.monitoring = false
	attack_hitbox.monitorable = false

	sprite.modulate = _idle_modulate
	is_attacking = false
	_next_attack_time = now + attack_cooldown


func _on_attack_body_entered(body: Node) -> void:
	if not body.is_in_group("enemies"):
		return

	if _hit_enemies.has(body):
		return

	_hit_enemies[body] = true

	if body.has_method("take_damage"):
		body.take_damage(1)

 

