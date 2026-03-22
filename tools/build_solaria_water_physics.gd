@tool
extends SceneTree
## One-off: adds full-tile physics on water atlas cells for Solaria tileset (player mask 1).

const TILE_HALF := 8.0
const SOURCE_ID := 1

# Detected from Solaria Demo Tiles.png (blue water; excludes obvious green grass).
const WATER_ATLAS: Array[Vector2i] = [
	Vector2i(10, 0), Vector2i(11, 0), Vector2i(12, 0), Vector2i(10, 1), Vector2i(11, 1), Vector2i(12, 1),
	Vector2i(10, 2), Vector2i(11, 2), Vector2i(12, 2), Vector2i(6, 3), Vector2i(9, 3), Vector2i(10, 3),
	Vector2i(11, 3), Vector2i(12, 3), Vector2i(6, 4), Vector2i(10, 4), Vector2i(11, 4), Vector2i(12, 4),
	Vector2i(10, 5), Vector2i(0, 6), Vector2i(2, 6), Vector2i(5, 6), Vector2i(6, 6), Vector2i(9, 6),
	Vector2i(10, 6), Vector2i(11, 6), Vector2i(12, 6), Vector2i(13, 6), Vector2i(15, 6), Vector2i(18, 6),
	Vector2i(0, 7), Vector2i(2, 7), Vector2i(5, 7), Vector2i(6, 7), Vector2i(13, 7), Vector2i(15, 7),
	Vector2i(18, 7), Vector2i(0, 8), Vector2i(1, 8), Vector2i(2, 8), Vector2i(3, 8), Vector2i(4, 8),
	Vector2i(5, 8), Vector2i(13, 8), Vector2i(14, 8), Vector2i(15, 8), Vector2i(16, 8), Vector2i(17, 8),
	Vector2i(18, 8), Vector2i(20, 8), Vector2i(22, 12), Vector2i(23, 12), Vector2i(9, 13), Vector2i(9, 14),
]


func _init() -> void:
	var path := "res://Assets/tilesets/tileMap2/solaria_level2_tileset.tres"
	var ts: TileSet = load(path) as TileSet
	if ts == null:
		push_error("Could not load TileSet")
		quit(1)
		return

	if ts.get_physics_layers_count() == 0:
		ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)

	var src := ts.get_source(SOURCE_ID) as TileSetAtlasSource
	if src == null:
		push_error("No atlas source ", SOURCE_ID)
		quit(1)
		return

	if src.texture_region_size == Vector2i.ZERO:
		src.texture_region_size = Vector2i(16, 16)

	var poly := PackedVector2Array([
		Vector2(-TILE_HALF, -TILE_HALF),
		Vector2(TILE_HALF, -TILE_HALF),
		Vector2(TILE_HALF, TILE_HALF),
		Vector2(-TILE_HALF, TILE_HALF),
	])

	for at in WATER_ATLAS:
		if not src.has_tile(at):
			src.create_tile(at)
		var td := src.get_tile_data(at, 0)
		while td.get_collision_polygons_count(0) > 0:
			td.remove_collision_polygon(0, 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, poly)

	var err := ResourceSaver.save(ts, path)
	print("save ", path, " err=", err)
	quit()
