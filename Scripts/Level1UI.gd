extends CanvasLayer

@onready var food_label: Label = $FoodLabel
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	if not Global.level1_food_updated.is_connected(_on_level1_food_updated):
		Global.level1_food_updated.connect(_on_level1_food_updated)
	Global.reset_level1()
	_on_level1_food_updated(Global.food_collected, Global.food_required)

	_rng.randomize()
	# Ensure Player/Food nodes are fully in the tree before we reposition them.
	await get_tree().process_frame
	_reposition_level1()


func _reposition_level1() -> void:
	var level_root := get_parent()
	if level_root == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size == Vector2.ZERO:
		return

	var kitchen := level_root.get_node_or_null("KitchenDecor")
	var play_rect := Rect2(Vector2.ZERO, viewport_size)
	var food_rect := Rect2(Vector2.ZERO, viewport_size)
	if kitchen != null:
		if kitchen.has_meta("kitchen_play_rect"):
			play_rect = kitchen.get_meta("kitchen_play_rect")
		if kitchen.has_meta("kitchen_food_rect"):
			food_rect = kitchen.get_meta("kitchen_food_rect")

	var center := play_rect.get_center()
	# Spawn foods only inside the kitchen area.
	var margin := 12.0
	var min_dist_from_player := 200.0
	var min_dist_between_food := 100.0
	var min_dist_from_obstacles := 44.0

	var player := level_root.get_node_or_null("Player") as Node2D
	if player == null:
		# Fallback: use group if Player node name differs.
		var grouped := get_tree().get_nodes_in_group("level1_player")
		if not grouped.is_empty() and grouped[0] is Node2D:
			player = grouped[0] as Node2D

	if player != null:
		player.global_position = center

	var food_nodes: Array[Node2D] = []
	for child in level_root.get_children():
		if child is Node2D and child.name.begins_with("Food_"):
			food_nodes.append(child as Node2D)

	var obstacle_nodes := get_tree().get_nodes_in_group("level1_obstacle")

	# Spread foods so they don't all cluster near (0,0) on large windows.
	var placed: Array[Vector2] = []
	for food in food_nodes:
		var pos := Vector2.ZERO
		var found := false
		for attempts in range(120):
			pos = Vector2(
				_rng.randf_range(food_rect.position.x + margin, food_rect.end.x - margin),
				_rng.randf_range(food_rect.position.y + margin, food_rect.end.y - margin)
			)

			if player != null and pos.distance_to(player.global_position) < min_dist_from_player:
				continue

			var too_close := false
			for p in placed:
				if pos.distance_to(p) < min_dist_between_food:
					too_close = true
					break
			if too_close:
				continue

			var blocked_by_obstacle := false
			for obstacle in obstacle_nodes:
				if not (obstacle is Node2D):
					continue
				var obstacle_node := obstacle as Node2D
				var avoid_radius := min_dist_from_obstacles
				if obstacle_node.has_meta("avoid_radius"):
					avoid_radius = float(obstacle_node.get_meta("avoid_radius")) + min_dist_from_obstacles
				if pos.distance_to(obstacle_node.global_position) < avoid_radius:
					blocked_by_obstacle = true
					break
			if blocked_by_obstacle:
				continue

			found = true
			break

		if not found:
			# Vẫn tránh lu / chướng ngại; chỉ nới khoảng cách giữa các món (không đặt chồng lên lu).
			var relaxed_between := min_dist_between_food * 0.55
			for _i in range(200):
				pos = Vector2(
					_rng.randf_range(food_rect.position.x + margin, food_rect.end.x - margin),
					_rng.randf_range(food_rect.position.y + margin, food_rect.end.y - margin)
				)
				var blocked := false
				for obstacle in obstacle_nodes:
					if not (obstacle is Node2D):
						continue
					var obstacle_node := obstacle as Node2D
					var avoid_radius := min_dist_from_obstacles
					if obstacle_node.has_meta("avoid_radius"):
						avoid_radius = float(obstacle_node.get_meta("avoid_radius")) + min_dist_from_obstacles
					if pos.distance_to(obstacle_node.global_position) < avoid_radius:
						blocked = true
						break
				if blocked:
					continue
				var ok_dist := true
				for p in placed:
					if pos.distance_to(p) < relaxed_between:
						ok_dist = false
						break
				if ok_dist:
					found = true
					break

		if not found:
			pos = food_rect.get_center()

		food.global_position = pos
		placed.append(pos)


func _on_level1_food_updated(collected: int, required: int) -> void:
	food_label.text = "Nhóc đi tìm đồ ăn: %d/%d" % [collected, required]
