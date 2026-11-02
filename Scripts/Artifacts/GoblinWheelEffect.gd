class_name GoblinWheelEffect
extends MagicArtifactEffect

## Every third completed wave offers three distinct battle-only buffs. The
## player chooses one without pausing combat, then the HUD wheel resolves that
## choice. Repeated awards stack.

signal buff_awarded(buff_id: StringName, stack_count: int)

const PANEL_SCRIPT := preload("res://Scripts/UI/Artifacts/GoblinWheelPanel.gd")
const BUFF_POOL: Array[Dictionary] = [
	{"id": &"ship_health", "label": "+25 SHIP HP", "short": "+25 HP"},
	{"id": &"flat_damage", "label": "WEAPON DAMAGE +1", "short": "DMG +1"},
	{"id": &"damage_percent", "label": "WEAPON DAMAGE +5%", "short": "DMG +5%"},
	{"id": &"weapon_range", "label": "WEAPON RANGE +10%", "short": "RANGE"},
	{"id": &"fire_rate", "label": "ATTACK SPEED +5%", "short": "RATE"},
	{"id": &"mining_rate", "label": "MINING +0.5 / SEC", "short": "MINE"},
]

var buff_stacks: Dictionary = {}
var _weapons: Array[WeaponModule] = []
var _miners: Array[MiningModule] = []
var _wave_manager: WaveManager
var _panel: GoblinWheelPanel
var _rng := RandomNumberGenerator.new()
var _pending_rolls: int = 0
var _roll_in_progress: bool = false


func _ready() -> void:
	if not is_instance_valid(ship):
		queue_free()
		return
	_rng.randomize()
	_register_module_providers()
	var battle := ship.get_parent()
	if battle != null:
		_wave_manager = battle.get_node_or_null("WaveManager") as WaveManager
		var ui_root := battle.get_node_or_null("BattleUI/UIRoot") as Control
		if ui_root != null:
			_panel = PANEL_SCRIPT.new() as GoblinWheelPanel
			_panel.name = "GoblinWheelPanel"
			ui_root.add_child(_panel)
			_panel.spin_finished.connect(_on_spin_finished)
			_panel.presentation_finished.connect(_on_presentation_finished)
	if is_instance_valid(_wave_manager):
		_wave_manager.wave_completed.connect(_on_wave_completed)


func _register_module_providers() -> void:
	if not is_instance_valid(ship) or ship.installed_modules == null:
		return
	for child in ship.installed_modules.get_children():
		if child is WeaponModule:
			var weapon := child as WeaponModule
			_weapons.append(weapon)
			weapon.add_artifact_base_damage_bonus(Callable(self, "_get_flat_damage_bonus"))
			weapon.add_artifact_damage_multiplier(Callable(self, "_get_damage_multiplier"))
			weapon.add_artifact_range_bonus(Callable(self, "_get_range_bonus"))
			weapon.add_artifact_fire_rate_bonus(Callable(self, "_get_fire_rate_bonus"))
		elif child is MiningModule:
			var miner := child as MiningModule
			_miners.append(miner)
			miner.add_artifact_mining_rate_bonus(Callable(self, "_get_mining_rate_bonus"))


func _on_wave_completed(wave_number: int, _total_waves: int) -> void:
	var interval := maxi(int(definition.effect_parameters.get("waves_per_roll", 3)), 1)
	if wave_number <= 0 or wave_number % interval != 0:
		return
	_pending_rolls += 1
	_try_start_roll()


func _try_start_roll() -> void:
	if _roll_in_progress or _pending_rolls <= 0:
		return
	_pending_rolls -= 1
	_roll_in_progress = true
	var offered := _pick_three_buffs()
	if is_instance_valid(_panel):
		_panel.start_spin(offered)
	else:
		var selected_index := _rng.randi_range(0, offered.size() - 1)
		apply_buff(StringName(offered[selected_index]["id"]))
		_roll_in_progress = false
		_try_start_roll()


func _pick_three_buffs() -> Array[Dictionary]:
	var remaining: Array[Dictionary] = BUFF_POOL.duplicate(true)
	var result: Array[Dictionary] = []
	while result.size() < 3 and not remaining.is_empty():
		var index := _rng.randi_range(0, remaining.size() - 1)
		result.append(remaining.pop_at(index))
	return result


func _on_spin_finished(buff_id: StringName) -> void:
	apply_buff(buff_id)


func _on_presentation_finished() -> void:
	_roll_in_progress = false
	_try_start_roll()


func apply_buff(buff_id: StringName) -> bool:
	if not BUFF_POOL.any(func(entry: Dictionary) -> bool: return StringName(entry["id"]) == buff_id):
		return false
	var new_count := int(buff_stacks.get(buff_id, 0)) + 1
	buff_stacks[buff_id] = new_count
	if buff_id == &"ship_health" and is_instance_valid(ship):
		var amount := maxf(float(definition.effect_parameters.get("ship_health", 25.0)), 0.0)
		ship.max_hp += amount
		ship.current_hp += amount
		ship.health_changed.emit(ship.current_hp, ship.max_hp)
	buff_awarded.emit(buff_id, new_count)
	return true


func get_buff_stacks(buff_id: StringName) -> int:
	return int(buff_stacks.get(buff_id, 0))


func get_total_rolls_awarded() -> int:
	var total := 0
	for count in buff_stacks.values():
		total += int(count)
	return total


func _get_flat_damage_bonus() -> float:
	return float(get_buff_stacks(&"flat_damage")) * maxf(float(definition.effect_parameters.get("flat_damage", 1.0)), 0.0)


func _get_damage_multiplier() -> float:
	return 1.0 + float(get_buff_stacks(&"damage_percent")) * maxf(float(definition.effect_parameters.get("damage_percent", 0.05)), 0.0)


func _get_range_bonus() -> float:
	return float(get_buff_stacks(&"weapon_range")) * maxf(float(definition.effect_parameters.get("weapon_range", 0.10)), 0.0)


func _get_fire_rate_bonus() -> float:
	return float(get_buff_stacks(&"fire_rate")) * maxf(float(definition.effect_parameters.get("fire_rate", 0.05)), 0.0)


func _get_mining_rate_bonus() -> float:
	return float(get_buff_stacks(&"mining_rate")) * maxf(float(definition.effect_parameters.get("mining_rate", 0.5)), 0.0)


func cleanup() -> void:
	if is_instance_valid(_wave_manager) and _wave_manager.wave_completed.is_connected(_on_wave_completed):
		_wave_manager.wave_completed.disconnect(_on_wave_completed)
	for weapon in _weapons:
		if not is_instance_valid(weapon):
			continue
		weapon.remove_artifact_base_damage_bonus(Callable(self, "_get_flat_damage_bonus"))
		weapon.remove_artifact_damage_multiplier(Callable(self, "_get_damage_multiplier"))
		weapon.remove_artifact_range_bonus(Callable(self, "_get_range_bonus"))
		weapon.remove_artifact_fire_rate_bonus(Callable(self, "_get_fire_rate_bonus"))
	for miner in _miners:
		if is_instance_valid(miner):
			miner.remove_artifact_mining_rate_bonus(Callable(self, "_get_mining_rate_bonus"))
	if is_instance_valid(ship):
		var health_bonus := float(get_buff_stacks(&"ship_health")) * maxf(float(definition.effect_parameters.get("ship_health", 25.0)), 0.0)
		if health_bonus > 0.0:
			ship.max_hp = maxf(ship.max_hp - health_bonus, 1.0)
			ship.current_hp = minf(ship.current_hp, ship.max_hp)
			ship.health_changed.emit(ship.current_hp, ship.max_hp)
	if is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null
	queue_free()
