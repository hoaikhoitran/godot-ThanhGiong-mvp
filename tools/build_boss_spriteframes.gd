extends SceneTree

func _init() -> void:
	var sf := SpriteFrames.new()

	var walk_01 := _load_tex("res://Assets/characters/boss/walk/walk_01.png")
	_add_frames(sf, "idle", [walk_01], true, 8.0)

	var walk_tex: Array[Texture2D] = []
	for i in range(1, 6):
		walk_tex.append(_load_tex("res://Assets/characters/boss/walk/walk_%02d.png" % i))
	_add_frames(sf, "walk", walk_tex, true, 10.0)

	var attack_tex: Array[Texture2D] = []
	for i in range(1, 6):
		attack_tex.append(_load_tex("res://Assets/characters/boss/attack/attack_%02d.png" % i))
	_add_frames(sf, "attack", attack_tex, false, 12.0)

	var hit_tex: Array[Texture2D] = [
		_load_tex("res://Assets/characters/boss/walk/walk_01.png"),
		_load_tex("res://Assets/characters/boss/walk/walk_02.png"),
	]
	_add_frames(sf, "hit", hit_tex, false, 14.0)

	var die_tex: Array[Texture2D] = [
		_load_tex("res://Assets/characters/boss/attack/attack_05.png"),
	]
	_add_frames(sf, "die", die_tex, false, 8.0)

	if sf.has_animation(&"default"):
		sf.remove_animation(&"default")

	var err := ResourceSaver.save(sf, "res://Assets/characters/boss/boss_sprite_frames.tres")
	if err != OK:
		push_error("save failed: %s" % err)
		quit(1)
		return
	print("Wrote res://Assets/characters/boss/boss_sprite_frames.tres")
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
