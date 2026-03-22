extends Node2D

const _TUTORIAL_TEXTURE := "res://Assets/ui/level1_tutorial_overlay.jpg"
## Must match Player.hunger_message_duration (intro lockout).
const _INTRO_DURATION_SEC := 3.0


func _ready() -> void:
	Global.ensure_level1_bgm_playing()
	await _show_tutorial_intro()


func _show_tutorial_intro() -> void:
	if not ResourceLoader.exists(_TUTORIAL_TEXTURE):
		push_warning("Level1: missing tutorial image: %s" % _TUTORIAL_TEXTURE)
		await get_tree().create_timer(_INTRO_DURATION_SEC).timeout
		Global.level1_intro_finished.emit()
		return
	var tex: Texture2D = load(_TUTORIAL_TEXTURE) as Texture2D
	if tex == null:
		await get_tree().create_timer(_INTRO_DURATION_SEC).timeout
		Global.level1_intro_finished.emit()
		return

	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.name = &"TutorialIntroLayer"

	var panel := Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.08, 0.08, 0.09, 0.88)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tr := TextureRect.new()
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.offset_left = 16.0
	tr.offset_top = 16.0
	tr.offset_right = -16.0
	tr.offset_bottom = -16.0
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	add_child(layer)
	layer.add_child(panel)
	panel.add_child(dim)
	panel.add_child(tr)

	await get_tree().create_timer(_INTRO_DURATION_SEC).timeout
	layer.queue_free()
	Global.level1_intro_finished.emit()
