extends Node2D

const _LEVEL1_BGM := "res://Assets/audio/level1_bgm.mp3"
## Audible over kitchen ambience; lower if it masks eat SFX.
## +6 dB vs the old −4 dB setting ≈ gấp đôi biên độ (âm lượng cảm nhận tăng rõ).
const _LEVEL1_BGM_DB := 2.0

const _TUTORIAL_TEXTURE := "res://Assets/ui/level1_tutorial_overlay.jpg"
## Must match Player.hunger_message_duration (intro lockout).
const _INTRO_DURATION_SEC := 3.0

var _bgm: AudioStreamPlayer


func _ready() -> void:
	_load_and_play_bgm()
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


func _load_and_play_bgm() -> void:
	if not FileAccess.file_exists(_LEVEL1_BGM):
		push_warning("Level1: BGM file missing: %s" % _LEVEL1_BGM)
		return
	var f := FileAccess.open(_LEVEL1_BGM, FileAccess.READ)
	if f == null:
		push_warning("Level1: could not open BGM (check import): %s" % _LEVEL1_BGM)
		return
	var mp3 := AudioStreamMP3.new()
	mp3.data = f.get_buffer(f.get_length())
	f.close()
	mp3.loop = true
	_bgm = AudioStreamPlayer.new()
	_bgm.name = &"Level1Bgm"
	_bgm.stream = mp3
	_bgm.volume_db = _LEVEL1_BGM_DB
	add_child(_bgm)
	_bgm.play()
