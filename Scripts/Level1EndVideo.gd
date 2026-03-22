extends Control

const NEXT_SCENE_PATH := "res://Scenes/Level2InstructionOverlay.tscn"

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer

var _transitioning: bool = false


func _ready() -> void:
	var stream := VideoStreamTheora.new()
	stream.file = "res://Assets/video/level1_end.ogv"
	video_player.stream = stream
	video_player.finished.connect(_on_video_finished)
	video_player.play()


func _on_video_finished() -> void:
	_go_to_next()


func _go_to_next() -> void:
	if _transitioning:
		return
	_transitioning = true
	video_player.stop()
	get_tree().change_scene_to_file(NEXT_SCENE_PATH)


func _unhandled_input(event: InputEvent) -> void:
	if _transitioning:
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			var tree := get_tree()
			if tree != null:
				tree.root.set_input_as_handled()
			_go_to_next()
