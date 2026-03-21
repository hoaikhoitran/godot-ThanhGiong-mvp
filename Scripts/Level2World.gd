extends Node2D

## Tile map size (tiles) and layout constants for Level 2 village.
const MAP_SIZE_TILES := Vector2i(60, 34)
const TILE_PX := 32

const _GRASS := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
const _DIRT_A := Vector2i(3, 0)
const _DIRT_B := Vector2i(4, 0)
const _WATER := Vector2i(5, 0)
const _BAMBOO_FLOOR := Vector2i(5, 1)
const _RICE_BG := Vector2i(0, 5)
const _ROOF := Vector2i(2, 2)
const _HOUSE := Vector2i(1, 3)
const _FENCE := Vector2i(0, 4)

## Central clearing reserved for UI / safe play (tile coords).
const UI_CLEAR_TILES := Rect2i(25, 13, 10, 8)

@onready var _bg: TileMapLayer = $TileMapLayer_Background
@onready var _ground: TileMapLayer = $TileMapLayer_Ground
@onready var _deco: TileMapLayer = $TileMapLayer_Decoration

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_paint_level()
	var px := Vector2(MAP_SIZE_TILES) * float(TILE_PX)
	set_meta("level2_map_bounds", Rect2(Vector2.ZERO, px))
	set_meta("level2_ui_exclusion", _ui_exclusion_rect_pixels())


func get_map_bounds() -> Rect2:
	return get_meta("level2_map_bounds") if has_meta("level2_map_bounds") else Rect2(Vector2.ZERO, Vector2(MAP_SIZE_TILES) * float(TILE_PX))


func get_ui_exclusion_rect() -> Rect2:
	return get_meta("level2_ui_exclusion") if has_meta("level2_ui_exclusion") else _ui_exclusion_rect_pixels()


func _ui_exclusion_rect_pixels() -> Rect2:
	return Rect2(
		Vector2(UI_CLEAR_TILES.position) * float(TILE_PX),
		Vector2(UI_CLEAR_TILES.size) * float(TILE_PX)
	)


func _paint_level() -> void:
	_bg.clear()
	_ground.clear()
	_deco.clear()

	for y in range(MAP_SIZE_TILES.y):
		for x in range(MAP_SIZE_TILES.x):
			var c := Vector2i(x, y)
			_bg.set_cell(c, 0, _rice_background_tile(c))
			_ground.set_cell(c, 0, _base_ground_tile(c))

	_apply_north_bamboo_band()
	_apply_side_rice_strips()
	_apply_water_ponds()
	_apply_main_paths()
	_apply_south_village()
	_preserve_center_clearing()


func _grass_rand() -> Vector2i:
	return _GRASS[_rng.randi() % _GRASS.size()]


func _base_ground_tile(c: Vector2i) -> Vector2i:
	# Northern forest floor
	if c.y < 6:
		return _pick([_BAMBOO_FLOOR, Vector2i(6, 1), Vector2i(7, 1)], c)
	return _grass_rand()


func _rice_background_tile(c: Vector2i) -> Vector2i:
	var stripe := (c.x / 3 + c.y / 2) % 2
	return Vector2i(2 + stripe * 2, 5)


func _apply_north_bamboo_band() -> void:
	for y in range(0, 6):
		for x in range(MAP_SIZE_TILES.x):
			var c := Vector2i(x, y)
			if UI_CLEAR_TILES.has_point(c):
				continue
			_ground.set_cell(c, 0, _pick([_BAMBOO_FLOOR, Vector2i(6, 1), Vector2i(7, 1)], c))
			if y < 4 and x % 2 == 0:
				_deco.set_cell(c, 0, _FENCE)
			elif y == 4:
				_deco.set_cell(c, 0, _ROOF)


func _apply_side_rice_strips() -> void:
	for y in range(6, MAP_SIZE_TILES.y - 8):
		for x in range(0, 8):
			var c := Vector2i(x, y)
			if UI_CLEAR_TILES.has_point(c):
				continue
			_bg.set_cell(c, 0, _RICE_BG)
			_ground.set_cell(c, 0, _DIRT_B if (x + y) % 2 == 0 else _grass_rand())
		for x in range(MAP_SIZE_TILES.x - 8, MAP_SIZE_TILES.x):
			var c := Vector2i(x, y)
			if UI_CLEAR_TILES.has_point(c):
				continue
			_bg.set_cell(c, 0, Vector2i(4, 5))
			_ground.set_cell(c, 0, _DIRT_A if (x + y) % 2 == 0 else _grass_rand())


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
				_ground.set_cell(c, 0, _WATER if (x + y) % 3 != 0 else Vector2i(6, 0))
				_deco.erase_cell(c)


func _apply_main_paths() -> void:
	var path_xs := [29, 30, 31]
	for y in range(8, MAP_SIZE_TILES.y - 2):
		for px in path_xs:
			var c := Vector2i(px, y)
			if UI_CLEAR_TILES.has_point(c):
				continue
			_ground.set_cell(c, 0, _DIRT_A if (px + y) % 2 == 0 else _DIRT_B)


func _apply_south_village() -> void:
	for y in range(MAP_SIZE_TILES.y - 7, MAP_SIZE_TILES.y):
		for x in range(MAP_SIZE_TILES.x):
			var c := Vector2i(x, y)
			if UI_CLEAR_TILES.has_point(c):
				continue
			_ground.set_cell(c, 0, _DIRT_A if (x + y) % 2 == 0 else _DIRT_B)
			if y == MAP_SIZE_TILES.y - 7 and x % 4 < 2:
				_deco.set_cell(c, 0, _ROOF)
			elif y >= MAP_SIZE_TILES.y - 5:
				if x % 5 == 0:
					_deco.set_cell(c, 0, _HOUSE)


func _preserve_center_clearing() -> void:
	for y in range(UI_CLEAR_TILES.position.y, UI_CLEAR_TILES.end.y):
		for x in range(UI_CLEAR_TILES.position.x, UI_CLEAR_TILES.end.x):
			var c := Vector2i(x, y)
			_bg.set_cell(c, 0, Vector2i(1, 5))
			_ground.set_cell(c, 0, _grass_rand())
			_deco.erase_cell(c)


func _pick(options: Array[Vector2i], c: Vector2i) -> Vector2i:
	var idx := int(absi(hash(c)) % options.size())
	return options[idx]
