extends CanvasLayer

const ENEMY_SCENE := preload("res://Scenes/Enemy.tscn")
const BOSS_SCENE := preload("res://Scenes/Boss.tscn")

@onready var enemy_remaining_label: Label = $EnemyRemainingLabel
@onready var boss_announce_label: Label = $BossAnnounceLabel
@onready var death_retry_overlay: Control = $DeathRetryOverlay
@onready var retry_button: TextureButton = $DeathRetryOverlay/RetryCenter/RetryButton
@export var level2_total_enemies: int = 8
@export var max_enemies_alive: int = 2

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()

	if not Global.level2_enemy_remaining_updated.is_connected(_on_level2_enemy_remaining_updated):
		Global.level2_enemy_remaining_updated.connect(_on_level2_enemy_remaining_updated)
	if not Global.level2_complete.is_connected(_on_level2_complete):
		Global.level2_complete.connect(_on_level2_complete)
	if not Global.level2_minions_cleared.is_connected(_on_level2_minions_cleared):
		Global.level2_minions_cleared.connect(_on_level2_minions_cleared)

	var level_root := get_parent()
	var _wait_frames := 0
	while level_root != null and not level_root.has_meta("level2_map_bounds"):
		await get_tree().process_frame
		_wait_frames += 1
		if _wait_frames > 180:
			break

	await get_tree().process_frame


	_clear_scene_enemies()

	await get_tree().process_frame

	var player := get_tree().get_first_node_in_group("level2_player")
	if player == null:
		player = level_root.get_node_or_null("Player_Adult")
	if player == null:
		var player_scene: PackedScene = preload("res://Scenes/Player_Adult.tscn")
		var new_player := player_scene.instantiate()
		level_root.add_child(new_player)
		player = new_player

	if player is Node2D:
		(player as Node2D).global_position = _get_spawn_position(level_root)

	await get_tree().process_frame

	Global.reset_level2(level2_total_enemies)

	if player.has_signal("died") and not player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died)

	retry_button.pressed.connect(_on_retry_button_pressed)


func _on_player_died() -> void:
	call_deferred("_show_death_retry_ui")


func _show_death_retry_ui() -> void:
	death_retry_overlay.visible = true
	get_tree().paused = true


func _on_retry_button_pressed() -> void:
	get_tree().paused = false
	# Một frame sau khi bỏ pause để SceneTree xử lý input/UI ổn định rồi mới nạp lại scene.
	await get_tree().process_frame
	get_tree().reload_current_scene()


func _clear_scene_enemies() -> void:
	for n in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(n):
			n.queue_free()
	await get_tree().process_frame


func _get_spawn_position(level_root: Node) -> Vector2:
	var marker := level_root.get_node_or_null("PlayerSpawn") as Marker2D
	if marker != null:
		return marker.global_position
	return _get_fallback_spawn(level_root)


func _get_fallback_spawn(level_root: Node) -> Vector2:
	if level_root.has_meta("level2_map_bounds"):
		var b: Rect2 = level_root.get_meta("level2_map_bounds") as Rect2
		return b.get_center()
	var size := get_viewport().get_visible_rect().size
	if size == Vector2.ZERO:
		return Vector2(320, 240)
	return size * 0.5


func _get_map_bounds(level_root: Node) -> Rect2:
	if level_root.has_meta("level2_map_bounds"):
		return level_root.get_meta("level2_map_bounds") as Rect2
	var s := get_viewport().get_visible_rect().size
	if s == Vector2.ZERO:
		s = Vector2(960, 540)
	return Rect2(Vector2.ZERO, s)


func _get_ui_exclusion_rect(level_root: Node) -> Rect2:
	if level_root.has_meta("level2_ui_exclusion"):
		return level_root.get_meta("level2_ui_exclusion") as Rect2
	return Rect2()


func _spawn_enemies_to_cap() -> void:
	if Global.is_level2_complete():
		return
	if not Global.is_level2_minion_spawn_allowed():
		return

	var alive := get_tree().get_nodes_in_group("enemies").size()
	if alive >= max_enemies_alive:
		return

	var need := max_enemies_alive - alive
	var spawn_n: int = min(need, Global.enemies_left)
	if spawn_n <= 0:
		return

	var level_root := get_parent()
	var player := get_tree().get_first_node_in_group("level2_player") as Node2D
	if player == null:
		return

	var map_bounds := _get_map_bounds(level_root)
	var ui_excl := _get_ui_exclusion_rect(level_root)

	for i in range(spawn_n):
		var inst: Node = ENEMY_SCENE.instantiate()
		level_root.add_child(inst)
		if inst is Node2D:
			_place_enemy_random(inst as Node2D, player, map_bounds, ui_excl)
		if inst.has_method("set_can_chase"):
			inst.call("set_can_chase", true)


func _place_enemy_random(
	enemy: Node2D,
	player: Node2D,
	map_bounds: Rect2,
	ui_excl: Rect2
) -> void:
	var margin := 64.0
	var min_dist_from_player := 120.0
	var player_pos := player.global_position

	var min_x := map_bounds.position.x + margin
	var max_x := map_bounds.position.x + map_bounds.size.x - margin
	var min_y := map_bounds.position.y + margin
	var max_y := map_bounds.position.y + map_bounds.size.y - margin
	if max_x <= min_x:
		max_x = min_x + 1.0
	if max_y <= min_y:
		max_y = min_y + 1.0

	var level_root := enemy.get_parent()
	var attempts := 0
	var pos := Vector2.ZERO
	var found := false
	while attempts < 128:
		pos = Vector2(
			_rng.randf_range(min_x, max_x),
			_rng.randf_range(min_y, max_y)
		)
		attempts += 1
		if not _is_spawn_tile_ok(level_root, pos):
			continue
		if ui_excl.size != Vector2.ZERO and ui_excl.has_point(pos):
			continue
		if pos.distance_to(player_pos) < min_dist_from_player:
			continue
		found = true
		break
	if not found:
		pos = _spawn_fallback_grid(
			level_root, map_bounds, ui_excl, player_pos, min_dist_from_player, margin
		)
	enemy.global_position = pos


func _is_spawn_tile_ok(level_root: Node, world_pos: Vector2) -> bool:
	if level_root == null:
		return true
	if level_root.has_method(&"level2_is_spawn_position_valid"):
		return bool(level_root.call(&"level2_is_spawn_position_valid", world_pos))
	return true


func _spawn_fallback_grid(
	level_root: Node,
	map_bounds: Rect2,
	ui_excl: Rect2,
	player_pos: Vector2,
	min_dist_from_player: float,
	margin: float
) -> Vector2:
	var min_x := map_bounds.position.x + margin
	var max_x := map_bounds.position.x + map_bounds.size.x - margin
	var min_y := map_bounds.position.y + margin
	var max_y := map_bounds.position.y + map_bounds.size.y - margin
	if max_x <= min_x:
		max_x = min_x + 1.0
	if max_y <= min_y:
		max_y = min_y + 1.0
	var step := 40.0
	var y := min_y
	while y <= max_y:
		var x := min_x
		while x <= max_x:
			var p := Vector2(x, y)
			if _is_spawn_tile_ok(level_root, p) \
					and (ui_excl.size == Vector2.ZERO or not ui_excl.has_point(p)) \
					and p.distance_to(player_pos) >= min_dist_from_player:
				return p
			x += step
		y += step
	for dist in [120.0, 180.0, 240.0, 300.0]:
		for i in range(8):
			var ang := TAU * float(i) / 8.0
			var ring_pos: Vector2 = player_pos + Vector2(cos(ang), sin(ang)) * dist
			ring_pos.x = clampf(ring_pos.x, min_x, max_x)
			ring_pos.y = clampf(ring_pos.y, min_y, max_y)
			if _is_spawn_tile_ok(level_root, ring_pos) \
					and (ui_excl.size == Vector2.ZERO or not ui_excl.has_point(ring_pos)) \
					and ring_pos.distance_to(player_pos) >= min_dist_from_player:
				return ring_pos
	return map_bounds.get_center()


func _on_level2_minions_cleared() -> void:
	enemy_remaining_label.text = "Nhiệm vụ: Đánh bại Boss Ân"
	boss_announce_label.visible = true
	await get_tree().create_timer(3.0).timeout
	boss_announce_label.visible = false
	_spawn_boss()


func _spawn_boss() -> void:
	var level_root := get_parent()
	if level_root == null:
		return
	var player := get_tree().get_first_node_in_group("level2_player") as Node2D
	if player == null:
		return
	var map_bounds := _get_map_bounds(level_root)
	var ui_excl := _get_ui_exclusion_rect(level_root)
	var inst: Node = BOSS_SCENE.instantiate()
	level_root.add_child(inst)
	if inst is Node2D:
		_place_enemy_random(inst as Node2D, player, map_bounds, ui_excl)
	if inst.has_method("set_can_chase"):
		inst.call("set_can_chase", true)
	Global.set_level2_boss_active()


func _on_level2_enemy_remaining_updated(remaining: int) -> void:
	if Global.level2_phase == Global.Level2Phase.MINIONS:
		enemy_remaining_label.text = "Kẻ địch còn lại: %d" % remaining
	call_deferred("_spawn_enemies_to_cap")


func _on_level2_complete() -> void:
	get_tree().change_scene_to_file("res://Scenes/Victory.tscn")
