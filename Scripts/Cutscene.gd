extends Control

@onready var dialogue_label: Label = $CenterContainer/DialogueLabel

var _dialogues: Array[String] = [
	"Cậu bé ăn bao nhiêu cũng không đủ, dù bà con cô bác khắp nơi đã góp gạo giúp đỡ.",
	"Trong căn bếp của mẹ vẫn còn vài món ăn sót lại.",
	"Hãy giúp cậu bé đi tìm hết đồ ăn trong bếp để cậu nhanh chóng lớn lên nhé!"
]

var _idx: int = 0
var _is_transitioning: bool = false
var _is_typing: bool = false

@export var chars_per_second: float = 35.0


func _ready() -> void:
	_idx = 0
	_setup_dialogue_layout()
	set_process(true)
	_update_text()


func _setup_dialogue_layout() -> void:
	# Ensure the label has enough width; otherwise autowrap can stack chars vertically.
	var view_size := get_viewport_rect().size
	var target_width := maxf(view_size.x * 0.8, 520.0)
	dialogue_label.custom_minimum_size = Vector2(target_width, 120.0)


func _update_text() -> void:
	dialogue_label.text = _dialogues[_idx]
	dialogue_label.visible_characters = 0
	_is_typing = true


func _process(delta: float) -> void:
	if not _is_typing:
		return

	var next_chars := dialogue_label.visible_characters + int(round(chars_per_second * delta))
	dialogue_label.visible_characters = min(next_chars, dialogue_label.text.length())
	if dialogue_label.visible_characters >= dialogue_label.text.length():
		_is_typing = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_advance()
		return

	if event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed:
		_advance()


func _advance() -> void:
	if _is_transitioning:
		return

	if _is_typing:
		dialogue_label.visible_characters = -1
		_is_typing = false
		return

	if _idx < _dialogues.size() - 1:
		_idx += 1
		_update_text()
		return

	_is_transitioning = true
	get_tree().change_scene_to_file("res://Scenes/Level_1.tscn")

 
