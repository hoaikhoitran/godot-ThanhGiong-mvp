extends SceneTree

func _init() -> void:
	var sf := SpriteFrames.new()

	var idle_tex: Array[Texture2D] = []
	for i in range(1, 5):
		idle_tex.append(_load_tex("res://Assets/characters/horse_rider/idle/idle_%02d.png" % i))
	_add_frames(sf, "idle", idle_tex, true, 7.0)

	# 5-frame gallop: 2 base + 3 extra frames for smoother loop.
	var run_tex: Array[Texture2D] = []
	for i in range(1, 6):
		run_tex.append(_load_tex("res://Assets/characters/horse_rider/run/run_%02d.png" % i))
	_add_frames(sf, "run", run_tex, true, 9.0)

	var a1: Array[Texture2D] = []
	for i in range(1, 4):
		a1.append(_load_tex("res://Assets/characters/horse_rider/attack1_swipe/attack1_swipe_%02d.png" % i))
	_add_frames(sf, "attack1_swipe", a1, false, 12.0)

	var a2: Array[Texture2D] = []
	for i in range(1, 5):
		a2.append(
			_load_tex(
				"res://Assets/characters/horse_rider/attack2_powerful_thrust/attack2_powerful_thrust_%02d.png" % i
			)
		)
	_add_frames(sf, "attack2_powerful_thrust", a2, false, 12.0)

	var blk: Array[Texture2D] = []
	for i in range(1, 6):
		blk.append(_load_tex("res://Assets/characters/horse_rider/block/block_%02d.png" % i))
	_add_frames(sf, "block", blk, true, 8.0)

	if sf.has_animation(&"default"):
		sf.remove_animation(&"default")

	var err := ResourceSaver.save(sf, "res://Assets/characters/horse_rider/horse_rider_sprite_frames.tres")
	if err != OK:
		push_error("save failed: %s" % err)
		quit(1)
		return
	print("Wrote res://Assets/characters/horse_rider/horse_rider_sprite_frames.tres")
	quit(0)


func _load_tex(path: String) -> Texture2D:
	var tex := load(path)
	if tex is Texture2D:
		return tex as Texture2D
	push_error("Not a Texture2D: %s" % path)
	return null


func _add_frames(
	sf: SpriteFrames,
	anim_name: String,
	textures: Array[Texture2D],
	loop: bool,
	fps: float,
) -> void:
	if not sf.has_animation(anim_name):
		sf.add_animation(anim_name)
	sf.set_animation_loop(anim_name, loop)
	sf.set_animation_speed(anim_name, fps)
	for tex in textures:
		if tex == null:
			push_error("null texture in %s" % anim_name)
			continue
		sf.add_frame(anim_name, tex)
