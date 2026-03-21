extends Control

@onready var play_again_button: Button = $CenterContainer/VBoxContainer/PlayAgainButton


func _ready() -> void:
	play_again_button.pressed.connect(_on_play_again_pressed)


func _on_play_again_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

 
