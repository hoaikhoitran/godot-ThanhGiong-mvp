extends Control

const MAIN_MENU_PATH := "res://Scenes/MainMenu.tscn"
const VICTORY_VIDEO_PATH := "res://Assets/video/victory.ogv"

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer
@onready var skip_label: Label = $SkipLabel
@onready var post_victory_ui: Control = $CenterContainer
@onready var play_again_button: Button = $CenterContainer/VBoxContainer/PlayAgainButton

var _post_ui_shown: bool = false


func _ready() -> void:
	post_victory_ui.visible = false
	play_again_button.pressed.connect(_on_play_again_pressed)

	var stream := VideoStreamTheora.new()
	stream.file = VICTORY_VIDEO_PATH
	video_player.stream = stream
	video_player.finished.connect(_on_video_finished)
	video_player.play()


func _on_video_finished() -> void:
	_show_post_victory_ui()


func _show_post_victory_ui() -> void:
	if _post_ui_shown:
		return
	_post_ui_shown = true
	video_player.stop()
	video_player.visible = false
	skip_label.visible = false
	post_victory_ui.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if _post_ui_shown:
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			var tree := get_tree()
			if tree != null:
				tree.root.set_input_as_handled()
			_show_post_victory_ui()


func _on_play_again_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
