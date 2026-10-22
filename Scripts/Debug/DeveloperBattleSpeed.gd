class_name DeveloperBattleSpeed
extends Node

## Battle-only playtest speed. Cinematics retain exclusive control of time.
signal speed_changed(selected_speed: float, effective_speed: float)
const BOSS_FINISHER := preload("res://Scripts/VFX/BossFinisher.gd")
const BATTLE_END_BEAT := preload("res://Scripts/VFX/BattleEndBeat.gd")
var selected_speed: float = 1.0
var _last_reported: float = -1.0
var _battle: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_battle = get_parent()

## Guard every command, including calls that do not originate from the UI.
func set_speed(value: float) -> bool:
	if not DeveloperCommands.is_available() or value not in [1.0, 2.0]:
		return false
	selected_speed = value
	_apply_speed()
	return true

func _process(_delta: float) -> void:
	if not DeveloperCommands.is_available():
		selected_speed = 1.0
	_apply_speed()

func _apply_speed() -> void:
	if not is_inside_tree() or _cinematic_owns_time():
		return
	var speed := 1.0 if _battle_is_over() or _qte_active() else selected_speed
	Engine.time_scale = speed
	if not is_equal_approx(speed, _last_reported):
		_last_reported = speed
		speed_changed.emit(selected_speed, speed)

func _battle_is_over() -> bool:
	return is_instance_valid(_battle) and bool(_battle.get("_battle_ended"))

func _cinematic_owns_time() -> bool:
	if is_instance_valid(BOSS_FINISHER._active):
		return true
	if is_instance_valid(BATTLE_END_BEAT._active):
		return true
	var tip: Variant = _battle.get("_evacuation_tip") if is_instance_valid(_battle) else null
	return is_instance_valid(tip) and (bool(tip.get("_active")) or bool(tip.get("_ending")))

func _qte_active() -> bool:
	if not is_instance_valid(_battle):
		return false
	var mining := _battle.get_node_or_null("MiningQteManager") as MiningQteManager
	if mining != null and mining.get_active_event_count() > 0:
		return true
	var weather := _battle.get_node_or_null("WeatherManager") as WeatherManager
	if weather != null and weather.is_input_frozen():
		return true
	for node in get_tree().get_nodes_in_group("boss_qte_targets"):
		if node.has_method("is_boss_qte_active") and node.call("is_boss_qte_active"):
			return true
	return false

func _exit_tree() -> void:
	Engine.time_scale = 1.0
