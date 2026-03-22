extends Node2D

const _LEVEL2_BGM := "res://Assets/audio/level2_bgm.mp3"
## Kept well under combat SFX (e.g. attack punch ~−3 dB) so hits stay readable.
const _LEVEL2_BGM_DB := -16.0

const _LEVEL2_BOSS_BGM := "res://Assets/audio/level2_boss_bgm.mp3"
## Slightly louder than exploration BGM when boss phase starts; still below loud SFX.
const _LEVEL2_BOSS_BGM_DB := -14.0

## Optional center area (tile cells) reserved for UI — used by Level2Manager spawn spread.
@export var ui_clear_tiles: Vector2i = Vector2i(12, 10)

## Atlas coords (Solaria) treated as water — CharacterBody2D collision_mask 1 blocks movement.
const _WATER_ATLAS: Array[Vector2i] = [
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

var _water_lookup: Dictionary = {}
var _bgm_player: AudioStreamPlayer
var _boss_bgm_player: AudioStreamPlayer


func _ready() -> void:
	for v in _WATER_ATLAS:
		_water_lookup[v] = true
	# Parent _ready runs after Level2Manager._ready; manager waits for this meta.
	_setup_map_meta()
	_setup_level2_bgm()
	if not Global.level2_minions_cleared.is_connected(_on_level2_minions_cleared_bgm):
		Global.level2_minions_cleared.connect(_on_level2_minions_cleared_bgm)


func _setup_level2_bgm() -> void:
	if not ResourceLoader.exists(_LEVEL2_BGM):
		return
	var stream: AudioStream = load(_LEVEL2_BGM) as AudioStream
	if stream == null:
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = &"Level2Bgm"
	_bgm_player.stream = stream
	_bgm_player.volume_db = _LEVEL2_BGM_DB
	add_child(_bgm_player)
	_bgm_player.play()


func _on_level2_minions_cleared_bgm() -> void:
	_switch_to_boss_bgm()


func _switch_to_boss_bgm() -> void:
	if _boss_bgm_player != null:
		return
	if _bgm_player != null:
		_bgm_player.stop()
		_bgm_player.queue_free()
		_bgm_player = null
	if not ResourceLoader.exists(_LEVEL2_BOSS_BGM):
		return
	var stream: AudioStream = load(_LEVEL2_BOSS_BGM) as AudioStream
	if stream == null:
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	_boss_bgm_player = AudioStreamPlayer.new()
	_boss_bgm_player.name = &"Level2BossBgm"
	_boss_bgm_player.stream = stream
	_boss_bgm_player.volume_db = _LEVEL2_BOSS_BGM_DB
	add_child(_boss_bgm_player)
	_boss_bgm_player.play()


func _setup_map_meta() -> void:
	var tm := get_node_or_null("TileMap") as TileMap
	if tm == null or tm.tile_set == null:
		return

	_build_water_collision(tm)
	_build_stuff_collision(tm)

	var ur := tm.get_used_rect()
	var tsz := Vector2(tm.tile_set.tile_size)
	var sc := tm.scale
	var origin := tm.global_position + Vector2(ur.position) * tsz * sc
	var px_size := Vector2(ur.size) * tsz * sc
	set_meta("level2_map_bounds", Rect2(origin, px_size))

	var stuff_layer: int = _tilemap_layer_index_by_name(tm, "Stuff")
	if stuff_layer >= 0:
		tm.set_layer_y_sort_enabled(stuff_layer, true)

	var mid_tile := Vector2(ur.position) + Vector2(ur.size) * 0.5
	var half_tl := Vector2(ui_clear_tiles) * 0.5
	var top_left_tile := mid_tile - half_tl
	var clr := Rect2(
		tm.global_position + top_left_tile * tsz * sc,
		Vector2(ui_clear_tiles) * tsz * sc
	)
	set_meta("level2_ui_exclusion", clr)


func _tilemap_layer_index_by_name(tm: TileMap, layer_name: String) -> int:
	for i in range(tm.get_layers_count()):
		if tm.get_layer_name(i) == layer_name:
			return i
	return -1


## Used by Level2Manager — reject water and any tile on the Stuff layer.
func level2_is_spawn_position_valid(world_pos: Vector2) -> bool:
	var tm := get_node_or_null("TileMap") as TileMap
	if tm == null:
		return true
	var local := tm.to_local(world_pos)
	var cell := tm.local_to_map(local)
	var stuff_id: int = _tilemap_layer_index_by_name(tm, "Stuff")
	for layer_id in range(tm.get_layers_count()):
		var atlas := tm.get_cell_atlas_coords(layer_id, cell)
		if atlas == Vector2i(-1, -1):
			continue
		if _water_lookup.has(atlas):
			return false
		if layer_id == stuff_id:
			return false
	return true


func _build_water_collision(tm: TileMap) -> void:
	var old := tm.get_node_or_null("WaterCollision")
	if old != null:
		old.queue_free()

	var sb := StaticBody2D.new()
	sb.name = "WaterCollision"
	sb.collision_layer = 1
	tm.add_child(sb)

	var tsz := Vector2(tm.tile_set.tile_size)
	for layer_id in range(tm.get_layers_count()):
		for c in tm.get_used_cells(layer_id):
			var atlas := tm.get_cell_atlas_coords(layer_id, c)
			if atlas == Vector2i(-1, -1):
				continue
			if not _water_lookup.has(atlas):
				continue
			var cs := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = tsz
			cs.shape = rect
			cs.position = tm.map_to_local(c) + tsz * 0.5
			sb.add_child(cs)


## Full-tile collision for every cell painted on the "Stuff" layer (props, trees, etc.).
func _build_stuff_collision(tm: TileMap) -> void:
	var old := tm.get_node_or_null("StuffCollision")
	if old != null:
		old.queue_free()
	var legacy := tm.get_node_or_null("DecorCollision")
	if legacy != null:
		legacy.queue_free()

	var layer_id: int = _tilemap_layer_index_by_name(tm, "Stuff")
	if layer_id < 0:
		return

	var sb := StaticBody2D.new()
	sb.name = "StuffCollision"
	sb.collision_layer = 1
	tm.add_child(sb)

	var tsz := Vector2(tm.tile_set.tile_size)
	for c in tm.get_used_cells(layer_id):
		var atlas := tm.get_cell_atlas_coords(layer_id, c)
		if atlas == Vector2i(-1, -1):
			continue
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = tsz
		cs.shape = rect
		cs.position = tm.map_to_local(c) + tsz * 0.5
		sb.add_child(cs)
