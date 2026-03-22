extends CharacterBody2D

const LEVEL1_END_VIDEO_SCENE := "res://Scenes/Level1EndVideo.tscn"

@export var move_speed: float = 150.0
@export var hunger_message_duration: float = 3.0
@export var transform_delay: float = 1.5
## Bắt đầu phát từ vị trí này (giây) trong file ăn — MP3 thường có ~1s im lặng đầu file, khiến âm thanh tưởng như trễ so với animation.
@export_range(0.0, 10.0, 0.01) var eat_sfx_play_from_seconds: float = 1.0

@onready var hunger_label: Label = $HungerLabel
@onready var sprite: Sprite2D = $Sprite2D
@onready var eat_food_sfx: AudioStreamPlayer = $EatFoodSfx

var _can_move: bool = false
var _transforming: bool = false

var _idle_modulate: Color = Color(1, 1, 1, 1)
var _walk_modulate: Color = Color(1, 1, 0.9, 1)
var _transform_modulate: Color = Color(1, 0.85, 0.65, 1)

var _fallback_texture: Texture2D

# Cached textures for Lv1 child animations (loaded from external asset pack).
var _child_idle_frames: Array[Texture2D] = []
var _child_walk_frames: Array[Texture2D] = []
var _child_transform_frames: Array[Texture2D] = []
var _child_eat_collect_frames: Array[Texture2D] = []
var _frames_loaded: bool = false

var _current_anim: String = "idle"
var _anim_time_accum: float = 0.0
var _anim_index: int = 0

# Visual override when picking up food (single-frame).
var _eat_override_time_left: float = 0.0

# Keep last movement direction so the sprite keeps "facing" even when idle.
var _last_move_dir: Vector2 = Vector2.RIGHT


func _apply_facing(move_dir: Vector2) -> void:
	# Snap to the dominant axis so we get stable 4-direction facing.
	if abs(move_dir.x) >= abs(move_dir.y):
		# Horizontal facing.
		sprite.flip_h = move_dir.x < 0.0
		sprite.rotation = 0.0
	else:
		# Vertical facing: keep rotation as-is (sprites are upright/top-down),
		# only ensure we don't keep a left/right flip.
		sprite.flip_h = false
		sprite.rotation = 0.0


func _clamp_to_viewport() -> void:
	# Prevent the player from leaving the playable kitchen area.
	var view := get_viewport().get_visible_rect()
	var kitchen := get_parent().get_node_or_null("KitchenDecor")
	var clamp_rect := view
	if kitchen != null and kitchen.has_meta("kitchen_play_rect"):
		clamp_rect = kitchen.get_meta("kitchen_play_rect")

	var gp := global_position

	# Use collision shape extents so we don't clamp too aggressively.
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

	gp.x = clamp(gp.x, clamp_rect.position.x + x_margin, clamp_rect.end.x - x_margin)
	gp.y = clamp(gp.y, clamp_rect.position.y + y_margin, clamp_rect.end.y - y_margin)
	global_position = gp


func _ready() -> void:
	add_to_group("level1_player")

	if not Global.level1_complete.is_connected(_on_level1_complete):
		Global.level1_complete.connect(_on_level1_complete)

	# Intro handled by Level1 (tutorial image 3s); stay still until timer ends.
	Global.player_can_move = false
	hunger_label.visible = false
	_can_move = false
	# Force visibility in case the sprite was hidden/fully transparent.
	sprite.visible = true
	sprite.modulate = _idle_modulate
	sprite.z_index = 10
	# Keep player smaller so the "searching" gameplay feels right.
	sprite.scale = Vector2(0.8, 0.8)

	_fallback_texture = sprite.texture
	_setup_child_lv1_animations()

	await Global.level1_intro_finished

	hunger_label.visible = false
	_can_move = true
	Global.player_can_move = true


func _physics_process(delta: float) -> void:
	if _transforming or not _can_move or not Global.player_can_move:
		velocity = Vector2.ZERO
		move_and_slide()

		_apply_facing(_last_move_dir)
		_clamp_to_viewport()

		if _transforming:
			sprite.modulate = _transform_modulate
			_play_child_anim(delta, "transform")
		else:
			sprite.modulate = _idle_modulate
			_play_child_anim(delta, "idle")

		return

	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir != Vector2.ZERO:
		_last_move_dir = dir
		_apply_facing(_last_move_dir)

	velocity = dir * move_speed
	move_and_slide()
	_clamp_to_viewport()
	if dir == Vector2.ZERO:
		sprite.modulate = _idle_modulate
		_play_child_anim(delta, "idle")
		_apply_facing(_last_move_dir)
	else:
		sprite.modulate = _walk_modulate
		_play_child_anim(delta, "walk")

func _on_level1_complete() -> void:
	if _transforming:
		return

	_transforming = true
	_can_move = false
	Global.player_can_move = false
	velocity = Vector2.ZERO
	move_and_slide()

	sprite.modulate = _transform_modulate
	_current_anim = "transform"
	_anim_time_accum = 0.0
	_anim_index = 0
	_play_child_anim(0.0, "transform")

	await get_tree().create_timer(transform_delay).timeout
	get_tree().change_scene_to_file(LEVEL1_END_VIDEO_SCENE)


func collect_food() -> void:
	# Called by Food.gd when the player touches a food item.
	_play_eat_food_sfx()
	Global.add_food()
	# Tiny visual feedback on pickup without affecting movement gating.
	if _frames_loaded and not _transforming and not _can_move:
		return
	if _frames_loaded and not _transforming:
		_eat_override_time_left = 0.15


func _play_eat_food_sfx() -> void:
	if eat_food_sfx.stream == null:
		return
	var pos := eat_sfx_play_from_seconds
	var stream_len := eat_food_sfx.stream.get_length()
	if stream_len > 0.0:
		pos = clampf(pos, 0.0, maxf(stream_len - 0.01, 0.0))
	eat_food_sfx.play(pos)


# -----------------------------
# Lv1 child animation helpers
# -----------------------------

func _asset_pack_sheets_dir() -> String:
	# Use project-bundled child sprite sheets.
	return "res://Assets/giong_godot_assets/sheets/"


func _slice_sheet(sheet_path: String, frame_width: int, frame_height: int, frame_count: int) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var atlas := ResourceLoader.load(sheet_path) as Texture2D
	if atlas == null:
		return out

	for i in range(frame_count):
		var frame := AtlasTexture.new()
		frame.atlas = atlas
		frame.region = Rect2(float(i * frame_width), 0.0, float(frame_width), float(frame_height))
		out.append(frame)

	return out


func _setup_child_lv1_animations() -> void:
	# Use aligned child sheets for more stable-looking animation.
	var base := _asset_pack_sheets_dir()

	_child_idle_frames.clear()
	_child_walk_frames.clear()
	_child_transform_frames.clear()
	_child_eat_collect_frames.clear()

	# Sizes/count come from giong_godot_assets manifest.
	_child_idle_frames = _slice_sheet(base + "child_idle_sheet.png", 75, 139, 1)
	_child_walk_frames = _slice_sheet(base + "child_walk_sheet.png", 100, 139, 4)
	_child_transform_frames = _slice_sheet(base + "child_transform_sheet.png", 125, 187, 3)
	_child_eat_collect_frames = _slice_sheet(base + "child_eat_collect_sheet.png", 108, 127, 1)

	_frames_loaded = not _child_idle_frames.is_empty() and not _child_walk_frames.is_empty()
	if not _frames_loaded:
		sprite.texture = _fallback_texture


func _play_child_anim(delta: float, anim_name: String) -> void:
	if not _frames_loaded:
		return

	# Override (food pickup) has priority over walking/idle.
	if _eat_override_time_left > 0.0 and not _transforming:
		_eat_override_time_left = maxf(_eat_override_time_left - delta, 0.0)
		if not _child_eat_collect_frames.is_empty():
			sprite.texture = _child_eat_collect_frames[0]
		return

	if _current_anim != anim_name:
		_current_anim = anim_name
		_anim_time_accum = 0.0
		_anim_index = 0

	var frames: Array[Texture2D] = []
	var fps: float = 8.0
	match anim_name:
		"idle":
			frames = _child_idle_frames
			fps = 8.0
		"walk":
			frames = _child_walk_frames
			fps = 8.0
		"transform":
			frames = _child_transform_frames
			fps = 6.0
		_:
			frames = _child_idle_frames

	if frames.is_empty():
		return

	var frame_duration := 1.0 / maxf(fps, 0.01)
	_anim_time_accum += delta

	# Advance frame based on accumulated time.
	while _anim_time_accum >= frame_duration and not frames.is_empty():
		_anim_time_accum -= frame_duration
		_anim_index = (_anim_index + 1) % frames.size()

	sprite.texture = frames[_anim_index]
