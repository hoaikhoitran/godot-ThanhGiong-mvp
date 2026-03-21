extends Area2D

@onready var sprite: Sprite2D = $Sprite2D

var _collected: bool = false
var _rng := RandomNumberGenerator.new()

const _FOOD_TEXTURES: Array[String] = [
	"res://Assets/food/food_1.png",
	"res://Assets/food/food_2.png",
	"res://Assets/food/food_3.png"
]

func _ready() -> void:
	_rng.randomize()
	# Randomize which food texture this instance shows.
	if _FOOD_TEXTURES.size() > 0 and sprite != null:
		var idx := _rng.randi_range(0, _FOOD_TEXTURES.size() - 1)
		var tex := ResourceLoader.load(_FOOD_TEXTURES[idx])
		if tex != null:
			sprite.texture = tex as Texture2D

	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _collected:
		return

	# Only collect food in Level 1.
	if not body.is_in_group("level1_player"):
		return

	_collected = true
	if body.has_method("collect_food"):
		body.call("collect_food")
	else:
		# Fallback to keep MVP robust if the touching body isn't the expected player.
		Global.add_food()

	# Prevent further collisions before freeing.
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	queue_free()

