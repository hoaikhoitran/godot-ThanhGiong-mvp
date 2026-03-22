extends Control

@onready var play_button: TextureButton = $CenterContainer/PlayButton
@onready var music_player: AudioStreamPlayer = $MusicPlayer


func _ready() -> void:
	play_button.pressed.connect(_on_play_button_pressed)
	var stream := music_player.stream
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	music_player.play()


func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Intro.tscn")
