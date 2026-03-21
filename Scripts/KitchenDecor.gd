extends Node2D

const FLOOR_TILE_PATH := "res://Assets/floor/level1_floor_tile_v2.png"
const FLOOR_TILE_SCALE := Vector2(0.55, 0.55)
const JAR_RAW_PATH := "res://Assets/props/jar_raw.jpg"
const BASKET_PATH := "res://Assets/props/basket_new.png"
const STOVE_PATH := "res://Assets/props/stove_new.png"
const PAN_PATH := "res://Assets/props/pan_new.png"

func _ready() -> void:
	var view := get_viewport_rect()
	var play_rect := Rect2(Vector2.ZERO, view.size)
	var food_rect := Rect2(
		play_rect.position + Vector2(28.0, 28.0),
		play_rect.size - Vector2(56.0, 56.0)
	)
	set_meta("kitchen_play_rect", play_rect)
	set_meta("kitchen_food_rect", food_rect)
	_build_floor(play_rect)
	_build_jar_decor()
	_build_extra_decor()


func _build_floor(play_rect: Rect2) -> void:
	var floor := Node2D.new()
	floor.name = "Floor"
	add_child(floor)

	var tex := load(FLOOR_TILE_PATH) as Texture2D
	if tex == null:
		return

	var tile_w := float(tex.get_width()) * FLOOR_TILE_SCALE.x
	var tile_h := float(tex.get_height()) * FLOOR_TILE_SCALE.y
	var cols := int(ceil(play_rect.size.x / tile_w)) + 1
	var rows := int(ceil(play_rect.size.y / tile_h)) + 1
	for y in range(rows):
		for x in range(cols):
			var tile := Sprite2D.new()
			tile.texture = tex
			tile.scale = FLOOR_TILE_SCALE
			tile.position = play_rect.position + Vector2(float(x) * tile_w + tile_w * 0.5, float(y) * tile_h + tile_h * 0.5)
			tile.z_index = -20
			floor.add_child(tile)


func _build_jar_decor() -> void:
	var jar_tex := _build_keyed_jar_texture()
	if jar_tex == null:
		return

	var decor := Node2D.new()
	decor.name = "JarDecor"
	add_child(decor)

	# Ít lọ hơn, đặt hai góc để nhường chỗ đặt thức ăn phía dưới.
	var positions := [
		Vector2(95, 118),
		Vector2(865, 125)
	]
	for pos in positions:
		var body := StaticBody2D.new()
		body.position = pos
		body.collision_layer = 2
		body.collision_mask = 0
		body.add_to_group("level1_obstacle")
		# Bán kính tránh spawn: sprite lu lớn hơn vòng va chạm — phải đủ rộng để thức ăn không nằm dưới hình lu.
		body.set_meta("avoid_radius", 95.0)
		decor.add_child(body)

		var s := Sprite2D.new()
		s.texture = jar_tex
		s.scale = Vector2(0.28, 0.28)
		s.z_index = 2
		body.add_child(s)

		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 20.0
		col.shape = shape
		col.position = Vector2(0, 6)
		body.add_child(col)


func _build_extra_decor() -> void:
	# Ít đồ trang trí: chỉ giỏ + bếp (bỏ chảo để giảm chồng với gameplay).
	_add_static_prop(BASKET_PATH, Vector2(180, 285), Vector2(0.85, 0.85), 16.0, 38.0)
	_add_static_prop(STOVE_PATH, Vector2(520, 275), Vector2(0.65, 0.65), 26.0, 56.0)


func _add_static_prop(texture_path: String, pos: Vector2, sprite_scale: Vector2, collision_radius: float, avoid_radius: float) -> void:
	var tex := load(texture_path) as Texture2D
	if tex == null:
		return

	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = 2
	body.collision_mask = 0
	body.add_to_group("level1_obstacle")
	body.set_meta("avoid_radius", avoid_radius)
	add_child(body)

	var s := Sprite2D.new()
	s.texture = tex
	s.scale = sprite_scale
	s.z_index = 2
	body.add_child(s)

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = collision_radius
	col.shape = shape
	col.position = Vector2(0, 6)
	body.add_child(col)


func _build_keyed_jar_texture() -> Texture2D:
	var src := load(JAR_RAW_PATH) as Texture2D
	if src == null:
		return null

	var img := src.get_image()
	if img == null:
		return null
	img.convert(Image.FORMAT_RGBA8)

	var w := img.get_width()
	var h := img.get_height()
	for y in range(h):
		for x in range(w):
			var c := img.get_pixel(x, y)
			var drg: float = absf(c.r - c.g)
			var dgb: float = absf(c.g - c.b)
			var is_gray: bool = drg < 0.06 and dgb < 0.06
			var is_bg: bool = is_gray and c.r > 0.62
			if is_bg:
				c.a = 0.0
			img.set_pixel(x, y, c)

	return ImageTexture.create_from_image(img)
