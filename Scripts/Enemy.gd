extends CharacterBody2D
class_name Enemy

enum AnimState { CHASE, HIT, ATTACK, DIE }

@export var max_health: int = 20
@export var move_speed: float = 110.0
## Seconds between damage ticks while the player stays inside the hurt area.
@export var hurt_player_interval: float = 1.5
## Damage dealt to the player per hit.
@export var damage_to_player: int = 5
## If true, death counts as the Level 2 boss (not a minion).
@export var is_boss: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurt_area: Area2D = $HurtPlayerArea
@onready var health_bar: Control = $HealthBar
@onready var green_bar: ProgressBar = $HealthBar/GreenBar
@onready var red_bar: ProgressBar = $HealthBar/RedBar
@onready var hide_bar_timer: Timer = $HealthBar/HideBarTimer
@onready var attack_sfx: AudioStreamPlayer = $EnemyAttackSfx
## Katana / swing khi kẻ địch (và boss) gây sát thương lên người chơi.
@export_file("*.mp3") var attack_sound_path: String = "res://Assets/audio/enemy_katana_attack.mp3"

var health: int = 20
var _home_position: Vector2
var _can_chase: bool = false
var _dead: bool = false
var _anim_lock: AnimState = AnimState.CHASE

var _hurt_cooldown_until: float = 0.0
## Tăng khi nhận sát thương / chết để huỷ chờ attack (play khác animation sẽ không emit animation_finished).
var _attack_swing_generation: int = 0


func _ready() -> void:
	health = max_health
	_home_position = position
	add_to_group("enemies")
	add_to_group("enemy")
	_setup_health_bars()
	hide_bar_timer.timeout.connect(_on_hide_bar_timeout)
	_load_mp3_into_player(attack_sfx, attack_sound_path)


func _load_mp3_into_player(player: AudioStreamPlayer, path: String) -> void:
	if path.is_empty():
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("Enemy: could not open attack SFX: %s" % path)
		return
	var mp3 := AudioStreamMP3.new()
	mp3.data = f.get_buffer(f.get_length())
	f.close()
	player.stream = mp3


func _process(delta: float) -> void:
	if not health_bar.visible:
		return
	if absf(red_bar.value - green_bar.value) > 0.001:
		red_bar.value = move_toward(red_bar.value, green_bar.value, delta * 120.0)


func set_can_chase(value: bool) -> void:
	_can_chase = value


func reset_to_home() -> void:
	position = _home_position


func _physics_process(_delta: float) -> void:
	if _dead:
		return

	if _anim_lock != AnimState.CHASE:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not _can_chase:
		velocity = Vector2.ZERO
		move_and_slide()
		_set_locomotion_anim(false)
		return

	var player := get_tree().get_first_node_in_group("level2_player") as Node2D
	if player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		_set_locomotion_anim(false)
		return

	var dir: Vector2 = player.global_position - global_position
	if dir.length() > 0.01:
		velocity = dir.normalized() * move_speed
		animated_sprite.flip_h = velocity.x < 0.0
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	_set_locomotion_anim(velocity.length_squared() > 0.0001)
	_try_damage_player_if_in_range()


func take_damage(amount: int = 1) -> void:
	if _dead:
		return
	_attack_swing_generation += 1
	health -= max(1, amount)
	_pulse_health_bar()
	if health <= 0:
		_die()
		return
	_anim_lock = AnimState.HIT
	velocity = Vector2.ZERO
	animated_sprite.play(&"hit")
	await animated_sprite.animation_finished
	if _dead:
		return
	_anim_lock = AnimState.CHASE


func _die() -> void:
	if _dead:
		return
	_attack_swing_generation += 1
	_dead = true
	velocity = Vector2.ZERO
	_anim_lock = AnimState.DIE
	hurt_area.set_deferred(&"monitoring", false)
	_can_chase = false
	animated_sprite.play(&"die")
	await animated_sprite.animation_finished
	# Drop from groups before notifying Global so Level2Manager's spawn cap
	# (get_nodes_in_group("enemies")) does not still count this dying node.
	remove_from_group(&"enemies")
	remove_from_group(&"enemy")
	if is_boss:
		Global.boss_defeated()
	else:
		Global.enemy_defeated_minion()
	queue_free()


func _try_damage_player_if_in_range() -> void:
	if _dead or _anim_lock != AnimState.CHASE or not _can_chase:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < _hurt_cooldown_until:
		return
	for body in hurt_area.get_overlapping_bodies():
		if not (body is Node2D):
			continue
		var b := body as Node2D
		if not b.is_in_group(&"level2_player"):
			continue
		_hurt_cooldown_until = now + maxf(0.05, hurt_player_interval)
		if b.has_method(&"take_damage"):
			b.call(&"take_damage", damage_to_player)
		_play_attack_moment()
		break


func _play_attack_moment() -> void:
	if _dead:
		return
	_anim_lock = AnimState.ATTACK
	velocity = Vector2.ZERO
	var gen := _attack_swing_generation
	if attack_sfx.stream != null:
		attack_sfx.play()
	animated_sprite.play(&"attack")
	var dur := _attack_anim_duration_seconds()
	await get_tree().create_timer(dur).timeout
	if _dead:
		return
	if gen != _attack_swing_generation:
		return
	_anim_lock = AnimState.CHASE
	var moving := false
	if _can_chase:
		var player := get_tree().get_first_node_in_group(&"level2_player") as Node2D
		if player != null:
			var dir := player.global_position - global_position
			moving = dir.length_squared() > 0.0001
	_set_locomotion_anim(moving)


func _attack_anim_duration_seconds() -> float:
	var sf := animated_sprite.sprite_frames
	if sf == null or not sf.has_animation(&"attack"):
		return 0.42
	var anim := &"attack"
	var speed: float = sf.get_animation_speed(anim)
	if speed <= 0.001:
		speed = 12.0
	var sum_dur := 0.0
	for i in range(sf.get_frame_count(anim)):
		sum_dur += sf.get_frame_duration(anim, i)
	return sum_dur / speed


func _set_locomotion_anim(moving: bool) -> void:
	if animated_sprite.animation == &"hit" \
			or animated_sprite.animation == &"attack" \
			or animated_sprite.animation == &"die":
		return
	if moving:
		if animated_sprite.animation != &"walk":
			animated_sprite.play(&"walk")
	else:
		if animated_sprite.animation != &"idle":
			animated_sprite.play(&"idle")


func _setup_health_bars() -> void:
	green_bar.min_value = 0.0
	red_bar.min_value = 0.0
	green_bar.max_value = float(max_health)
	red_bar.max_value = float(max_health)
	green_bar.value = float(max_health)
	red_bar.value = float(max_health)
	health_bar.visible = false

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.08, 0.85)
	var fill_g := StyleBoxFlat.new()
	fill_g.bg_color = Color(0.2, 0.78, 0.35)
	var fill_r := StyleBoxFlat.new()
	fill_r.bg_color = Color(0.72, 0.18, 0.18)
	green_bar.add_theme_stylebox_override(&"background", bg)
	red_bar.add_theme_stylebox_override(&"background", bg)
	green_bar.add_theme_stylebox_override(&"fill", fill_g)
	red_bar.add_theme_stylebox_override(&"fill", fill_r)
	green_bar.z_index = 1
	red_bar.z_index = 0


func _pulse_health_bar() -> void:
	green_bar.value = float(health)
	health_bar.visible = true
	hide_bar_timer.start()


func _on_hide_bar_timeout() -> void:
	health_bar.visible = false
