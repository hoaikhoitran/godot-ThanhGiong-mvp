@tool
extends SceneTree
## One-off: generates res://Assets/tilesets/mystic_woods/mystic_woods.tres
func _init() -> void:
	var ts := TileSet.new()
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)

	var plains_tex: Texture2D = load("res://Assets/tilesets/mystic_woods/sprites/tilesets/plains.png")
	var water_tex: Texture2D = load("res://Assets/tilesets/mystic_woods/sprites/tilesets/water1.png")
	var decor_tex: Texture2D = load("res://Assets/tilesets/mystic_woods/sprites/tilesets/decor_16x16.png")

	var plains := TileSetAtlasSource.new()
	plains.texture = plains_tex
	plains.texture_region_size = Vector2i(16, 16)
	var plains_id := ts.add_source(plains)

	var water := TileSetAtlasSource.new()
	water.texture = water_tex
	water.texture_region_size = Vector2i(16, 16)
	var water_id := ts.add_source(water)

	var decor := TileSetAtlasSource.new()
	decor.texture = decor_tex
	decor.texture_region_size = Vector2i(16, 16)
	var decor_id := ts.add_source(decor)

	# Create tiles for all non-empty regions (Mystic sheets are tight-packed).
	for sid in [plains_id, water_id, decor_id]:
		var src := ts.get_source(sid) as TileSetAtlasSource
		var gw: int = int(src.texture.get_width()) / src.texture_region_size.x
		var gh: int = int(src.texture.get_height()) / src.texture_region_size.y
		for x in range(gw):
			for y in range(gh):
				var at := Vector2i(x, y)
				if not src.has_tile(at):
					src.create_tile(at)

	# Water: block all tiles on water atlas.
	for x in range(6):
		for y in range(4):
			_set_full_physics(ts, water_id, Vector2i(x, y))

	# Plains: cliff / trunk rows (y>=6) block movement.
	for x in range(6):
		for y in range(6, 12):
			_set_full_physics(ts, plains_id, Vector2i(x, y))

	# Decor: tree trunks (rows 1–3) — bottom half collision; rocks row 4 full-ish.
	for x in range(4):
		for y in range(1, 4):
			_set_trunk_physics(ts, decor_id, Vector2i(x, y))
	for x in range(4):
		_set_full_physics(ts, decor_id, Vector2i(x, 4))

	var err := ResourceSaver.save(ts, "res://Assets/tilesets/mystic_woods/mystic_woods.tres")
	print("save: ", err)
	quit()


func _set_full_physics(ts: TileSet, source_id: int, at: Vector2i) -> void:
	var poly := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	_apply_physics(ts, source_id, at, poly)


func _set_trunk_physics(ts: TileSet, source_id: int, at: Vector2i) -> void:
	# Lower half of 16×16 tile (origin at tile center).
	var poly := PackedVector2Array([Vector2(-8, 0), Vector2(8, 0), Vector2(8, 8), Vector2(-8, 8)])
	_apply_physics(ts, source_id, at, poly)


func _apply_physics(ts: TileSet, source_id: int, at: Vector2i, poly: PackedVector2Array) -> void:
	var src := ts.get_source(source_id) as TileSetAtlasSource
	var td := src.get_tile_data(at, 0)
	td.add_collision_polygon(0)
	td.set_collision_polygon_points(0, 0, poly)
