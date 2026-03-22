extends Node

# --- Level 1 API (required by spec) ---
var food_collected: int = 0
var food_required: int = 10

# --- Level 2 API (required by spec) ---
## Counts minions only (not the boss).
var enemies_left: int = 0

enum Level2Phase {
	MINIONS,
	BOSS_PENDING,
	BOSS_ACTIVE,
	DONE,
}

## Minions → boss intro → boss fight → victory.
var level2_phase: Level2Phase = Level2Phase.MINIONS

# --- Shared API (required by spec) ---
# Player movement gate used by Player scripts.
var player_can_move: bool = true

var _level1_complete_emitted: bool = false
var _level2_complete_emitted: bool = false
var _level2_minions_cleared_emitted: bool = false

# Signals (used by UI and scene managers)
signal level1_food_updated(collected: int, required: int)
## Emitted once when Level 1 tutorial image intro has finished (e.g. 3s overlay).
signal level1_intro_finished()
signal level1_complete()
signal level2_enemy_remaining_updated(remaining: int)
## Emitted once when the last minion dies (before boss spawns).
signal level2_minions_cleared()
signal level2_complete()


func _ready() -> void:
	_ensure_attack_action()
	_ensure_movement_actions()


func _ensure_attack_action() -> void:
	# The project declares `attack`, but the action can be empty.
	# If so, we add `J` and `Space` events.
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")

	var events := InputMap.action_get_events("attack")
	if events.is_empty():
		_add_attack_events()


func _add_attack_events() -> void:
	var ev1 := InputEventKey.new()
	ev1.keycode = KEY_J
	InputMap.action_add_event("attack", ev1)

	var ev2 := InputEventKey.new()
	ev2.keycode = KEY_SPACE
	InputMap.action_add_event("attack", ev2)


func _ensure_movement_actions() -> void:
	# Ensure actions exist even if the project accidentally removed default mappings.
	# Player.gd uses Input.get_vector(...), PlayerAdult.gd uses Input.get_axis(...).
	_ensure_key_event("ui_left", KEY_LEFT)
	_ensure_key_event("ui_left", KEY_A)
	_ensure_key_event("ui_right", KEY_RIGHT)
	_ensure_key_event("ui_right", KEY_D)
	_ensure_key_event("ui_up", KEY_UP)
	_ensure_key_event("ui_up", KEY_W)
	_ensure_key_event("ui_down", KEY_DOWN)
	_ensure_key_event("ui_down", KEY_S)


func _ensure_key_event(action_name: String, keycode: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for ev in InputMap.action_get_events(action_name):
		if ev is InputEventKey and ev.keycode == keycode:
			return

	var new_ev := InputEventKey.new()
	new_ev.keycode = keycode
	InputMap.action_add_event(action_name, new_ev)


func reset_level1() -> void:
	food_collected = 0
	_level1_complete_emitted = false
	player_can_move = true
	emit_signal("level1_food_updated", food_collected, food_required)


func reset_level2(enemy_count: int) -> void:
	enemies_left = max(enemy_count, 0)
	_level2_complete_emitted = false
	_level2_minions_cleared_emitted = false
	level2_phase = Level2Phase.MINIONS
	player_can_move = true
	emit_signal("level2_enemy_remaining_updated", enemies_left)


func add_food() -> void:
	# Only Level 1 uses this.
	if is_level1_complete():
		return

	food_collected = min(food_collected + 1, food_required)
	emit_signal("level1_food_updated", food_collected, food_required)

	if is_level1_complete() and not _level1_complete_emitted:
		_level1_complete_emitted = true
		player_can_move = false
		emit_signal("level1_complete")


func enemy_defeated_minion() -> void:
	if level2_phase != Level2Phase.MINIONS:
		return
	if _level2_complete_emitted:
		return

	enemies_left = max(enemies_left - 1, 0)
	emit_signal("level2_enemy_remaining_updated", enemies_left)

	if enemies_left == 0 and not _level2_minions_cleared_emitted:
		_level2_minions_cleared_emitted = true
		level2_phase = Level2Phase.BOSS_PENDING
		emit_signal("level2_minions_cleared")


func set_level2_boss_active() -> void:
	if level2_phase == Level2Phase.BOSS_PENDING:
		level2_phase = Level2Phase.BOSS_ACTIVE


func boss_defeated() -> void:
	if level2_phase != Level2Phase.BOSS_ACTIVE:
		return
	if _level2_complete_emitted:
		return
	_level2_complete_emitted = true
	level2_phase = Level2Phase.DONE
	player_can_move = false
	emit_signal("level2_complete")


## True once the boss is dead and Victory should run.
func is_level2_complete() -> bool:
	return _level2_complete_emitted


func is_level2_minion_spawn_allowed() -> bool:
	return level2_phase == Level2Phase.MINIONS and enemies_left > 0


func is_level1_complete() -> bool:
	return food_collected >= food_required
