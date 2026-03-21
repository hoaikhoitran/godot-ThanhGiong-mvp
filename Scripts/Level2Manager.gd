extends CanvasLayer

@onready var enemy_remaining_label: Label = $EnemyRemainingLabel
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()

	if not Global.level2_enemy_remaining_updated.is_connected(_on_level2_enemy_remaining_updated):
		Global.level2_enemy_remaining_updated.connect(_on_level2_enemy_remaining_updated)
	if not Global.level2_complete.is_connected(_on_level2_complete):
		Global.level2_complete.connect(_on_level2_complete)

	# Wait for enemies to finish entering the scene and add themselves to the groups.
	await get_tree().process_frame

	var level_root := get_parent()

	# Ensure Player exists and is placed correctly. Some setups may leave it at (0,0).
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

	# Wait for Player's _ready() to add it to the right group.
	await get_tree().process_frame

	var count := get_tree().get_nodes_in_group("enemies").size()
	_spread_enemies_randomly(player)
	Global.reset_level2(count)

	# Only start chasing after Player is ready; also reset homes to avoid clustering.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("reset_to_home"):
			enemy.reset_to_home()
		if enemy.has_method("set_can_chase"):
			enemy.set_can_chase(true)


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


func _spread_enemies_randomly(player: Node) -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return

	var level_root := get_parent()
	var map_bounds := _get_map_bounds(level_root)
	var ui_excl := _get_ui_exclusion_rect(level_root)

	var margin := 64.0
	var min_dist_from_player := 120.0
	var player_pos := (player as Node2D).global_position if player is Node2D else _get_spawn_position(level_root)

	var min_x := map_bounds.position.x + margin
	var max_x := map_bounds.position.x + map_bounds.size.x - margin
	var min_y := map_bounds.position.y + margin
	var max_y := map_bounds.position.y + map_bounds.size.y - margin
	if max_x <= min_x:
		max_x = min_x + 1.0
	if max_y <= min_y:
		max_y = min_y + 1.0

	for enemy in enemies:
		if not (enemy is Node2D):
			continue

		var node := enemy as Node2D
		var attempts := 0
		var pos := Vector2.ZERO
		while attempts < 48:
			pos = Vector2(
				_rng.randf_range(min_x, max_x),
				_rng.randf_range(min_y, max_y)
			)
			if not ui_excl.has_point(pos):
				if pos.distance_to(player_pos) >= min_dist_from_player:
					break
			attempts += 1
		node.global_position = pos


func _on_level2_enemy_remaining_updated(remaining: int) -> void:
	enemy_remaining_label.text = "Kẻ địch còn lại: %d" % remaining


func _on_level2_complete() -> void:
	get_tree().change_scene_to_file("res://Scenes/Victory.tscn")
