extends Control

const LEVEL1_SCENE := "res://Scenes/Level_1.tscn"
const SLIDE_PATHS: Array[String] = [
	"res://Assets/ui/loi_thoai_1.png",
	"res://Assets/ui/loi_thoai_2.png",
	"res://Assets/ui/loi_thoai_3.png",
]

@onready var texture_rect: TextureRect = $TextureRect

var _idx: int = 0
var _transitioning: bool = false


func _ready() -> void:
	Global.ensure_level1_bgm_playing()
	_apply_slide()


func _apply_slide() -> void:
	var path := SLIDE_PATHS[_idx]
	if not ResourceLoader.exists(path):
		push_warning("OpeningDialogue: missing texture %s" % path)
		return
	var tex := load(path) as Texture2D
	if tex != null:
		texture_rect.texture = tex


func _advance() -> void:
	if _transitioning:
		return
	if _idx < SLIDE_PATHS.size() - 1:
		_idx += 1
		_apply_slide()
		return
	_transitioning = true
	get_tree().change_scene_to_file(LEVEL1_SCENE)


func _input(event: InputEvent) -> void:
	if _transitioning:
		return
	if event.is_action_pressed("ui_accept"):
		_advance()
		return
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		_advance()
