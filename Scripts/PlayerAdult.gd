extends CharacterBody2D

signal health_changed(current: int, max_h: int)
signal died

@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D
@onready var attack1_sfx: AudioStreamPlayer = $Attack1Sfx
@onready var attack2_punch_sfx: AudioStreamPlayer = $Attack2PunchSfx

@export var max_health: int = 100
@export var move_speed: float = 200.0
@export var attack_cooldown: float = 0.4
## Primary swing (attack1) hitbox window.
@export var attack_duration: float = 0.26
## Sound played when starting primary attack (chiêu 1). Loaded from project at runtime.
@export_file("*.mp3") var attack1_sound_path: String = "res://Assets/audio/punch_attack1.mp3"
## Sound for secondary attack; loaded at runtime (optional).
@export_file("*.mp3") var attack2_sound_path: String = "res://Assets/audio/attack2_punch.mp3"
## Secondary swing (attack2) hitbox window.
@export var attack2_duration: float = 0.36
@export var attack_range_distance: float = 54.0
## Seconds before attack2 can be used again after a swing.
var attack2_cooldown_duration: float = 10.0

var _next_attack_time: float = 0.0
## Wall-clock seconds when attack2 is ready (cooldown ends).
var attack2_ready_at: float = 0.0
var is_attacking: bool = false
var is_blocking: bool = false
var _last_facing: Vector2 = Vector2.RIGHT

var _idle_modulate: Color = Color(1, 1, 1, 1)
var _attack_modulate: Color = Color(1, 0.75, 0.6, 1)

var _current_swing_damage: int = 5

# Prevents damaging the same enemy multiple times during one attack swing.
var _hit_enemies: Dictionary = {}

## Bumped when a swing is cancelled (e.g. block); awaited swings ignore cleanup if stale.
var _swing_generation: int = 0

var _play_bounds: Rect2 = Rect2()
var _bounds_ready: bool = false

var health: int = 100


func get_attack2_cooldown_remaining() -> float:
	var now := Time.get_ticks_msec() / 1000.0
	return maxf(0.0, attack2_ready_at - now)


func _clamp_to_play_bounds() -> void:
	if not _bounds_ready:
		return
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
	health = max_health
	add_to_group("level2_player")
	attack_hitbox.monitoring = false
	attack_hitbox.body_entered.connect(_on_attack_body_entered)
	emit_signal("health_changed", health, max_health)

	sprite.visible = true
	sprite.modulate = _idle_modulate
	sprite.z_index = 10
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"idle"):
		sprite.play(&"idle")

	call_deferred("_apply_level2_bounds")
	_load_mp3_stream(attack1_sfx, attack1_sound_path, "attack1")
	_load_mp3_stream(attack2_punch_sfx, attack2_sound_path, "attack2")


func _load_mp3_stream(player: AudioStreamPlayer, path: String, label: String) -> void:
	if path.is_empty():
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("PlayerAdult: could not open %s SFX: %s" % [label, path])
		return
	var mp3 := AudioStreamMP3.new()
	mp3.data = f.get_buffer(f.get_length())
	f.close()
	player.stream = mp3


func _apply_level2_bounds() -> void:
	var lr := get_parent()
	if lr != null and lr.has_meta("level2_map_bounds"):
		_play_bounds = lr.get_meta("level2_map_bounds") as Rect2
	else:
		_play_bounds = get_viewport().get_visible_rect()

	if camera != null:
		camera.position = Vector2.ZERO
		var b := _play_bounds
		camera.limit_left = int(floor(b.position.x))
		camera.limit_top = int(floor(b.position.y))
		camera.limit_right = int(ceil(b.end.x))
		camera.limit_bottom = int(ceil(b.end.y))
		camera.make_current()

	_bounds_ready = true


func _physics_process(_delta: float) -> void:
	is_blocking = Input.is_action_pressed(&"block")
	if is_blocking and is_attacking:
		_cancel_attack_swing()
	var dir := _get_move_vector()

	if dir.length() > 1.0:
		dir = dir.normalized()

	if dir != Vector2.ZERO:
		_last_facing = _direction_to_cardinal(dir)

	sprite.flip_h = _last_facing.x < 0.0

	if not Global.player_can_move:
		velocity = Vector2.ZERO
		move_and_slide()
		_clamp_to_play_bounds()
		_refresh_anim()
		return

	if is_blocking:
		velocity = dir * move_speed * 0.4
		move_and_slide()
		_clamp_to_play_bounds()
		_refresh_anim()
		return

	velocity = dir * move_speed
	move_and_slide()
	_clamp_to_play_bounds()

	var now := Time.get_ticks_msec() / 1000.0
	if not is_attacking:
		if Input.is_action_just_pressed(&"attack_secondary") and now >= attack2_ready_at:
			_start_attack_secondary(now)
		elif (
			(
				Input.is_action_just_pressed(&"attack_primary")
				or Input.is_action_just_pressed(&"attack")
			)
			and now >= _next_attack_time
		):
			_start_attack_primary(now)

	_refresh_anim()


func _get_move_vector() -> Vector2:
	if InputMap.has_action(&"move_left") and InputMap.has_action(&"move_right") \
			and InputMap.has_action(&"move_up") and InputMap.has_action(&"move_down"):
		return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var x := Input.get_axis(&"ui_left", &"ui_right")
	var y := Input.get_axis(&"ui_up", &"ui_down")
	return Vector2(x, y)


func _direction_to_cardinal(dir: Vector2) -> Vector2:
	if abs(dir.x) >= abs(dir.y):
		return Vector2.RIGHT if dir.x >= 0.0 else Vector2.LEFT
	return Vector2.DOWN if dir.y >= 0.0 else Vector2.UP


func _cancel_attack_swing() -> void:
	attack_hitbox.monitoring = false
	attack_hitbox.monitorable = false
	is_attacking = false
	sprite.modulate = _idle_modulate
	_swing_generation += 1


func _refresh_anim() -> void:
	if is_blocking:
		if sprite.animation != &"block":
			sprite.play(&"block")
		return
	if is_attacking:
		return
	var moving := velocity.length_squared() > 4.0
	if moving:
		if sprite.animation != &"run":
			sprite.play(&"run")
	else:
		if sprite.animation != &"idle":
			sprite.play(&"idle")


func _start_attack_primary(now: float) -> void:
	var gen := _swing_generation
	is_attacking = true
	_hit_enemies.clear()
	_current_swing_damage = 5

	var facing := _last_facing
	attack_hitbox.position = facing * attack_range_distance

	sprite.play(&"attack1_swipe")
	sprite.modulate = _attack_modulate
	if attack1_sfx.stream != null:
		attack1_sfx.play()

	attack_hitbox.monitoring = true
	attack_hitbox.monitorable = true
	await get_tree().create_timer(attack_duration).timeout
	if gen != _swing_generation:
		return

	attack_hitbox.monitoring = false
	attack_hitbox.monitorable = false

	sprite.modulate = _idle_modulate
	is_attacking = false
	_next_attack_time = now + attack_cooldown


func _start_attack_secondary(now: float) -> void:
	var gen := _swing_generation
	is_attacking = true
	_hit_enemies.clear()
	_current_swing_damage = 10
	attack2_ready_at = now + attack2_cooldown_duration

	if attack2_punch_sfx.stream != null:
		attack2_punch_sfx.play()

	var facing := _last_facing
	attack_hitbox.position = facing * attack_range_distance

	sprite.play(&"attack2_powerful_thrust")
	sprite.modulate = _attack_modulate

	attack_hitbox.monitoring = true
	attack_hitbox.monitorable = true
	await get_tree().create_timer(attack2_duration).timeout
	if gen != _swing_generation:
		return

	attack_hitbox.monitoring = false
	attack_hitbox.monitorable = false

	sprite.modulate = _idle_modulate
	is_attacking = false
	_next_attack_time = now + attack_cooldown


func _on_attack_body_entered(body: Node) -> void:
	if not body.is_in_group(&"enemies"):
		return

	if _hit_enemies.has(body):
		return

	_hit_enemies[body] = true

	if body.has_method(&"take_damage"):
		body.take_damage(_current_swing_damage)


func take_damage(amount: int) -> void:
	if is_blocking:
		return
	if health <= 0:
		return
	health = max(0, health - max(1, amount))
	emit_signal("health_changed", health, max_health)
	_flash_damage()
	if health <= 0:
		emit_signal("died")
		Global.player_can_move = false


func _base_modulate_for_flash() -> Color:
	if is_attacking:
		return _attack_modulate
	return _idle_modulate


func _flash_damage() -> void:
	var restore := _base_modulate_for_flash()
	var t := create_tween()
	t.tween_property(sprite, ^"modulate", Color(1, 0.45, 0.45, 1), 0.06)
	t.tween_property(sprite, ^"modulate", restore, 0.12)
