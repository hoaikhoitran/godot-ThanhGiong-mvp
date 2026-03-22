extends Node2D

## Tile map size (tile cells) and world scale for Level 2 (Mystic Woods).
## Native art is 16×16; TileMapLayers use scale 2 so one cell = 32 world pixels.
const MAP_SIZE_TILES := Vector2i(60, 34)
const TILE_PX := 32

const SRC_PLAINS := 0
const SRC_WATER := 1
const SRC_DECOR := 2

const _GRASS_X := [0, 1, 2]
const _DIRT_A := Vector2i(3, 4)
const _DIRT_B := Vector2i(4, 4)

## Central clearing reserved for UI / safe play (tile coords).
const UI_CLEAR_TILES := Rect2i(25, 13, 10, 8)

@onready var _bg: TileMapLayer = $TileMapLayer_Background
@onready var _ground: TileMapLayer = $TileMapLayer_Ground
@onready var _deco: TileMapLayer = $TileMapLayer_Decoration


func _ready() -> void:
	_paint_level()
	var px := Vector2(MAP_SIZE_TILES) * float(TILE_PX)
	# World-space rect so Player_Adult clamp/camera match the full grass field (meta is read after parent _ready).
	set_meta("level2_map_bounds", Rect2(global_position, px))
	set_meta("level2_ui_exclusion", _ui_exclusion_rect_pixels())


func get_map_bounds() -> Rect2:
	if has_meta("level2_map_bounds"):
		return get_meta("level2_map_bounds") as Rect2
	return Rect2(global_position, Vector2(MAP_SIZE_TILES) * float(TILE_PX))


func get_ui_exclusion_rect() -> Rect2:
	return get_meta("level2_ui_exclusion") if has_meta("level2_ui_exclusion") else _ui_exclusion_rect_pixels()


## Used by Level2Manager so enemies are not spawned on water tiles.
func level2_is_spawn_position_valid(world_pos: Vector2) -> bool:
	var local := _ground.to_local(world_pos)
	var cell := _ground.local_to_map(local)
	return _ground.get_cell_source_id(cell) != SRC_WATER


func _ui_exclusion_rect_pixels() -> Rect2:
	return Rect2(
		global_position + Vector2(UI_CLEAR_TILES.position) * float(TILE_PX),
		Vector2(UI_CLEAR_TILES.size) * float(TILE_PX)
	)


func _paint_level() -> void:
	_bg.clear()
	_ground.clear()
	_deco.clear()

	for y in range(MAP_SIZE_TILES.y):
		for x in range(MAP_SIZE_TILES.x):
			var c := Vector2i(x, y)
			_bg.set_cell(c, SRC_PLAINS, _bg_tile(c))
			_ground.set_cell(c, SRC_PLAINS, _grass_tile(c))

	_apply_outer_forest()
	_apply_water_ponds()
	_apply_main_paths()
	_apply_south_clearing()
	_preserve_center_clearing()


func _bg_tile(_c: Vector2i) -> Vector2i:
	# Slight variation, deterministic (no RNG).
	return Vector2i(0, 0)


func _grass_tile(c: Vector2i) -> Vector2i:
	var gx := int(absi((c.x * 31) ^ (c.y * 17))) % _GRASS_X.size()
	return Vector2i(_GRASS_X[gx], 0)


func _apply_outer_forest() -> void:
	var margin := 4
	for y in range(MAP_SIZE_TILES.y):
		for x in range(MAP_SIZE_TILES.x):
			var c := Vector2i(x, y)
			if UI_CLEAR_TILES.has_point(c):
				continue
			if x < margin or x >= MAP_SIZE_TILES.x - margin \
					or y < margin or y >= MAP_SIZE_TILES.y - margin:
				var tx := (x + y * 3) % 6
				_ground.set_cell(c, SRC_PLAINS, Vector2i(tx, 8))
				if (x + y) % 4 == 0:
					_deco.set_cell(c, SRC_DECOR, Vector2i((x >> 1) % 4, 2))


func _apply_water_ponds() -> void:
	var ponds: Array[Rect2i] = [
		Rect2i(4, 10, 9, 8),
		Rect2i(47, 9, 9, 9),
	]
	for r in ponds:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				if UI_CLEAR_TILES.has_point(c):
					continue
				var wx := (x + y) % 6
				var wy := ((x >> 1) + y) % 4
				_ground.set_cell(c, SRC_WATER, Vector2i(wx, wy))
				_deco.erase_cell(c)


func _apply_main_paths() -> void:
	var path_xs := [29, 30, 31]
	for y in range(8, MAP_SIZE_TILES.y - 2):
		for px in path_xs:
			var c := Vector2i(px, y)
			if UI_CLEAR_TILES.has_point(c):
				continue
			_ground.set_cell(c, SRC_PLAINS, _DIRT_A if (px + y) % 2 == 0 else _DIRT_B)


func _apply_south_clearing() -> void:
	for y in range(MAP_SIZE_TILES.y - 7, MAP_SIZE_TILES.y):
		for x in range(MAP_SIZE_TILES.x):
			var c := Vector2i(x, y)
			if UI_CLEAR_TILES.has_point(c):
				continue
			_ground.set_cell(c, SRC_PLAINS, _DIRT_A if (x + y) % 2 == 0 else _DIRT_B)
			if y >= MAP_SIZE_TILES.y - 4 and x % 6 == 0:
				_deco.set_cell(c, SRC_DECOR, Vector2i(1, 4))


func _preserve_center_clearing() -> void:
	for y in range(UI_CLEAR_TILES.position.y, UI_CLEAR_TILES.end.y):
		for x in range(UI_CLEAR_TILES.position.x, UI_CLEAR_TILES.end.x):
			var c := Vector2i(x, y)
			_bg.set_cell(c, SRC_PLAINS, Vector2i(1, 0))
			_ground.set_cell(c, SRC_PLAINS, _grass_tile(c))
			_deco.erase_cell(c)
