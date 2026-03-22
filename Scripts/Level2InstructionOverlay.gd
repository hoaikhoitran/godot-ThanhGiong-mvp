extends Control

const NEXT_SCENE_PATH := "res://Scenes/map_lv_2_new.tscn"
const TEXTURE_PATH := "res://Assets/ui/level2_instruction_overlay.jpg"
const DISPLAY_SEC := 3.0

@onready var texture_rect: TextureRect = $TextureRect

var _done: bool = false


func _ready() -> void:
	if ResourceLoader.exists(TEXTURE_PATH):
		var tex := load(TEXTURE_PATH) as Texture2D
		if tex != null:
			texture_rect.texture = tex
	else:
		push_warning("Level2InstructionOverlay: missing texture %s" % TEXTURE_PATH)

	get_tree().create_timer(DISPLAY_SEC).timeout.connect(_go_next)


func _go_next() -> void:
	if _done:
		return
	_done = true
	get_tree().change_scene_to_file(NEXT_SCENE_PATH)


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			var tree := get_tree()
			if tree != null:
				tree.root.set_input_as_handled()
			_go_next()
