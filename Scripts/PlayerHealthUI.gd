extends CanvasLayer

@onready var bar: ProgressBar = $Root/Bar
@onready var label: Label = $Root/Label
@onready var attack2_panel: Control = $Root/Attack2Panel
@onready var attack2_label: Label = $Root/Attack2Panel/Attack2Label
@onready var attack2_bar: ProgressBar = $Root/Attack2Panel/Attack2Bar

var _player: Node = null


func _ready() -> void:
	layer = 11
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.12, 0.14, 0.92)
	bar.add_theme_stylebox_override(&"background", bg)
	var bg2 := StyleBoxFlat.new()
	bg2.bg_color = Color(0.12, 0.12, 0.14, 0.92)
	attack2_bar.add_theme_stylebox_override(&"background", bg2)
	var fill2 := StyleBoxFlat.new()
	fill2.bg_color = Color(0.45, 0.55, 0.95)
	attack2_bar.add_theme_stylebox_override(&"fill", fill2)
	call_deferred(&"_bind_player")


func _process(_delta: float) -> void:
	_update_attack2_ui()


func _bind_player() -> void:
	var p := get_tree().get_first_node_in_group(&"level2_player") as Node
	if p == null:
		return
	_player = p
	if p.has_signal(&"health_changed"):
		if not p.health_changed.is_connected(_on_health_changed):
			p.health_changed.connect(_on_health_changed)
		_on_health_changed(p.health, p.max_health)


func _on_health_changed(current: int, max_h: int) -> void:
	label.text = "HP: %d/%d" % [current, max_h]
	bar.max_value = max_h
	bar.value = current
	var ratio := float(current) / float(max_h) if max_h > 0 else 0.0
	_apply_bar_color(ratio)


func _apply_bar_color(ratio: float) -> void:
	var fill: Color
	if ratio > 0.6:
		fill = Color(0.2, 0.75, 0.35)
	elif ratio > 0.3:
		fill = Color(0.9, 0.75, 0.2)
	else:
		fill = Color(0.85, 0.2, 0.2)
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	bar.add_theme_stylebox_override(&"fill", sb)


func _update_attack2_ui() -> void:
	if _player == null:
		_bind_player()
	if _player == null:
		attack2_panel.visible = false
		return
	if not _player.has_method(&"get_attack2_cooldown_remaining"):
		attack2_panel.visible = false
		return
	var rem: float = _player.call(&"get_attack2_cooldown_remaining")
	var max_cd := 10.0
	# Node.get() expects NodePath (child path); use Object.get via call for a script property.
	var raw_cd: Variant = _player.call(&"get", &"attack2_cooldown_duration")
	if typeof(raw_cd) == TYPE_FLOAT or typeof(raw_cd) == TYPE_INT:
		max_cd = float(raw_cd)
	attack2_bar.max_value = max_cd
	attack2_bar.value = rem
	if rem > 0.05:
		attack2_panel.visible = true
		attack2_label.text = "Đòn 2: %.1fs" % rem
	else:
		attack2_panel.visible = false
