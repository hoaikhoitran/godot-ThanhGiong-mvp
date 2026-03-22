extends CanvasLayer

const ENEMY_SCENE := preload("res://Scenes/Enemy.tscn")
const BOSS_SCENE := preload("res://Scenes/Boss.tscn")
const HEALTH_POTION_SCENE := preload("res://Scenes/HealthPotion.tscn")

@onready var enemy_remaining_label: Label = $EnemyRemainingLabel
@onready var boss_announce_label: Label = $BossAnnounceLabel
@onready var block_hint_label: Label = $BlockHintLabel
@onready var toast_label: Label = $ToastLabel
@onready var death_retry_overlay: Control = $DeathRetryOverlay
@onready var retry_button: TextureButton = $DeathRetryOverlay/RetryCenter/RetryButton
@export var level2_total_enemies: int = 8
@export var max_enemies_alive: int = 2
@export var initial_health_potions: int = 3

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
		_spawn_health_potions(level_root, player as Node2D)

	await get_tree().process_frame

	Global.reset_level2(level2_total_enemies)

	if player.has_signal("died") and not player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died)

	retry_button.pressed.connect(_on_retry_button_pressed)
	_show_toast("Bao ve lang, tieu diet giac An", 2.2)
	_show_block_hint_temporarily()


func _on_player_died() -> void:
	call_deferred("_show_death_retry_ui")


func _show_death_retry_ui() -> void:
	death_retry_overlay.visible = true
	get_tree().paused = true


func _on_retry_button_pressed() -> void:
	get_tree().paused = false
	# Một frame sau khi bỏ pause để SceneTree xử lý input/UI ổn định rồi mới nạp lại scene.
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://Scenes/map_lv_2_new.tscn")


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


func _spawn_health_potions(level_root: Node, player: Node2D) -> void:
	if initial_health_potions <= 0:
		return
	if HEALTH_POTION_SCENE == null:
		return

	var map_bounds := _get_map_bounds(level_root)
	var ui_excl := _get_ui_exclusion_rect(level_root)
	var placed_positions: Array[Vector2] = []

	for i in range(initial_health_potions):
		var item: Node = HEALTH_POTION_SCENE.instantiate()
		level_root.add_child(item)
		if item is Node2D:
			_place_pickup_random(item as Node2D, player, map_bounds, ui_excl, placed_positions)


func _place_pickup_random(
	item: Node2D,
	player: Node2D,
	map_bounds: Rect2,
	ui_excl: Rect2,
	occupied_positions: Array[Vector2]
) -> void:
	var margin := 56.0
	var min_dist_from_player := 64.0
	var min_dist_between_pickups := 72.0
	var player_pos := player.global_position

	var min_x := map_bounds.position.x + margin
	var max_x := map_bounds.position.x + map_bounds.size.x - margin
	var min_y := map_bounds.position.y + margin
	var max_y := map_bounds.position.y + map_bounds.size.y - margin
	if max_x <= min_x:
		max_x = min_x + 1.0
	if max_y <= min_y:
		max_y = min_y + 1.0

	var level_root: Node = item.get_parent()
	var attempts: int = 0
	var pos := Vector2.ZERO
	var found: bool = false
	while attempts < 192:
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
		var too_close_to_other := false
		for p: Vector2 in occupied_positions:
			if pos.distance_to(p) < min_dist_between_pickups:
				too_close_to_other = true
				break
		if too_close_to_other:
			continue
		found = true
		break

	if not found:
		pos = _spawn_fallback_ring(
			level_root,
			map_bounds,
			ui_excl,
			player_pos,
			min_dist_from_player,
			margin,
			occupied_positions,
			min_dist_between_pickups
		)

	item.global_position = pos
	occupied_positions.append(pos)


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


func _spawn_fallback_ring(
	level_root: Node,
	map_bounds: Rect2,
	ui_excl: Rect2,
	player_pos: Vector2,
	min_dist_from_player: float,
	margin: float,
	occupied_positions: Array[Vector2],
	min_dist_between_pickups: float
) -> Vector2:
	var min_x := map_bounds.position.x + margin
	var max_x := map_bounds.position.x + map_bounds.size.x - margin
	var min_y := map_bounds.position.y + margin
	var max_y := map_bounds.position.y + map_bounds.size.y - margin
	if max_x <= min_x:
		max_x = min_x + 1.0
	if max_y <= min_y:
		max_y = min_y + 1.0

	var ring_distances: Array[float] = [90.0, 130.0, 170.0, 220.0, 280.0]
	for dist: float in ring_distances:
		for i in range(18):
			var ang: float = _rng.randf_range(0.0, TAU)
			var p: Vector2 = player_pos + Vector2(cos(ang), sin(ang)) * dist
			p.x = clampf(p.x, min_x, max_x)
			p.y = clampf(p.y, min_y, max_y)
			if not _is_spawn_tile_ok(level_root, p):
				continue
			if ui_excl.size != Vector2.ZERO and ui_excl.has_point(p):
				continue
			if p.distance_to(player_pos) < min_dist_from_player:
				continue
			var too_close_to_other := false
			for existing: Vector2 in occupied_positions:
				if p.distance_to(existing) < min_dist_between_pickups:
					too_close_to_other = true
					break
			if too_close_to_other:
				continue
			return p

	return _spawn_fallback_grid(
		level_root,
		map_bounds,
		ui_excl,
		player_pos,
		min_dist_from_player,
		margin
	)


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
	enemy_remaining_label.text = "NHIEM VU: Danh bai Boss An"
	_show_boss_announce("Boss An xuat hien", 5.0)
	_show_toast("Can than don tan cong manh", 2.4)
	await get_tree().create_timer(2.7).timeout
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
		enemy_remaining_label.text = "NHIEM VU: Tieu diet giac An (%d)" % remaining
	call_deferred("_spawn_enemies_to_cap")


func _on_level2_complete() -> void:
	_show_toast("Chien thang!", 0.8)
	get_tree().change_scene_to_file("res://Scenes/Victory.tscn")


func _show_block_hint_temporarily() -> void:
	block_hint_label.visible = true
	await get_tree().create_timer(7.0).timeout
	block_hint_label.visible = false


func _show_boss_announce(message: String, duration: float = 7.0) -> void:
	boss_announce_label.text = message
	boss_announce_label.visible = true
	var base_y := boss_announce_label.position.y
	boss_announce_label.position.y = base_y - 12.0
	boss_announce_label.modulate = Color(1, 1, 1, 0)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(boss_announce_label, ^"modulate:a", 1.0, 0.18)
	t.tween_property(boss_announce_label, ^"position:y", base_y, 0.18)
	t.set_parallel(false)
	t.tween_interval(maxf(0.3, duration))
	t.set_parallel(true)
	t.tween_property(boss_announce_label, ^"modulate:a", 0.0, 0.2)
	t.tween_property(boss_announce_label, ^"position:y", base_y - 8.0, 0.2)
	t.finished.connect(func() -> void:
		boss_announce_label.visible = false
		boss_announce_label.position.y = base_y
	)


func _show_toast(message: String, duration: float = 1.8) -> void:
	toast_label.text = message
	toast_label.visible = true
	var base_y := toast_label.position.y
	toast_label.position.y = base_y + 10.0
	toast_label.modulate = Color(1, 1, 1, 0)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(toast_label, ^"modulate:a", 1.0, 0.16)
	t.tween_property(toast_label, ^"position:y", base_y, 0.16)
	t.set_parallel(false)
	t.tween_interval(maxf(0.2, duration))
	t.set_parallel(true)
	t.tween_property(toast_label, ^"modulate:a", 0.0, 0.2)
	t.tween_property(toast_label, ^"position:y", base_y - 8.0, 0.2)
	t.finished.connect(func() -> void:
		toast_label.visible = false
		toast_label.position.y = base_y
	)
