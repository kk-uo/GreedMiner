extends Node

const SAVE := preload("res://Tests/TestSave.gd")
const SHIP := preload("res://Scenes/Ship/ship.tscn")
const GUN_PATH := "res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn"
const MINER_PATH := "res://Scenes/Modules/Mining/mining_module.tscn"
const PANEL_SCRIPT := preload("res://Scripts/UI/Artifacts/GoblinWheelPanel.gd")

var failures: Array[String] = []
var _panel_result: StringName = &""
var _wave_completion_count: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SAVE.isolate("goblin_wheel")
	ShipLoadout.install_module(0, 0, GUN_PATH)
	ShipLoadout.install_module(0, 1, MINER_PATH)
	ResearchManager.progress.levels["weapon_damage.machine_gun"] = 1
	var definition := ArtifactManager.get_definition(&"goblin_wheel")
	_check(definition != null and definition.rarity == "Legendary", "Goblin Wheel is registered as Legendary")
	_check(definition.equip_target == MagicArtifactDefinition.EquipTarget.SHIP, "Goblin Wheel equips to the ship")
	_check(definition.source_planet_id == &"goblin_planet" and not definition.mining_chest_reward, "Goblin Wheel is a Verdant boss reward")
	_check(ArtifactManager.grant_artifact(&"goblin_wheel"), "Goblin Wheel can be granted once")
	_check(not ArtifactManager.grant_artifact(&"goblin_wheel"), "Goblin Wheel is unique")
	ResearchManager.progress.levels["ship_magic_slot_1"] = 1
	_check(ArtifactManager.equip_ship_artifact(0, &"goblin_wheel"), "Goblin Wheel equips in a ship artifact slot")

	var ship := SHIP.instantiate() as Ship
	add_child(ship)
	await get_tree().process_frame
	var gun := ship.get_module_at(0, 0) as MachineGun
	var miner := ship.get_module_at(0, 1) as MiningModule
	_check(gun != null and miner != null, "test ship loads weapon and mining modules")
	var base_hp := ship.max_hp
	var base_damage := gun.get_damage()
	var base_rate := gun.get_fire_rate()
	var base_range := gun.get_modified_attack_range(gun.attack_range)
	var base_mining := miner.get_effective_ore_per_second()

	var effect := definition.effect_script.new() as GoblinWheelEffect
	effect.configure(definition, ship)
	add_child(effect)
	await get_tree().process_frame
	_check(effect.apply_buff(&"ship_health"), "health buff applies")
	_check(is_equal_approx(ship.max_hp, base_hp + 25.0) and is_equal_approx(ship.current_hp, ship.max_hp), "health buff adds 25 maximum and current HP")
	_check(effect.apply_buff(&"flat_damage"), "flat damage buff applies")
	_check(is_equal_approx(gun.get_damage(), base_damage + 1.0), "flat damage buff adds one base damage")
	_check(effect.apply_buff(&"damage_percent"), "percent damage buff applies")
	_check(is_equal_approx(gun.get_damage(), (base_damage + 1.0) * 1.05), "damage buff adds five percent")
	effect.apply_buff(&"damage_percent")
	_check(is_equal_approx(gun.get_damage(), (base_damage + 1.0) * 1.10), "repeat percent buffs stack additively")
	effect.apply_buff(&"weapon_range")
	_check(is_equal_approx(gun.get_modified_attack_range(gun.attack_range), base_range * 1.10), "range buff adds ten percent")
	effect.apply_buff(&"fire_rate")
	_check(is_equal_approx(gun.get_fire_rate(), base_rate * 1.05), "attack speed buff adds five percent")
	effect.apply_buff(&"mining_rate")
	_check(is_equal_approx(miner.get_effective_ore_per_second(), base_mining + 0.5), "mining buff adds 0.5 ore per second")
	_check(not effect.apply_buff(&"unknown"), "unknown buffs are rejected")

	var offered := effect._pick_three_buffs()
	var offered_ids: Dictionary = {}
	for entry in offered:
		offered_ids[StringName(entry["id"])] = true
	_check(offered.size() == 3 and offered_ids.size() == 3, "each roll offers three distinct buffs")
	var manager := WaveManager.new()
	var config := PlanetWaveConfig.new()
	var completed_wave := WaveDefinition.new()
	completed_wave.wave_number = 3
	config.waves = [completed_wave]
	manager.wave_config = config
	_wave_completion_count = 0
	manager.wave_completed.connect(func(_wave: int, _total: int) -> void: _wave_completion_count += 1)
	manager._mark_wave_completed(completed_wave)
	manager._mark_wave_completed(completed_wave)
	_check(_wave_completion_count == 1, "WaveManager emits completion only once per wave")

	effect.cleanup()
	await get_tree().process_frame
	_check(is_equal_approx(ship.max_hp, base_hp), "battle cleanup removes health stacks")
	_check(is_equal_approx(gun.get_damage(), base_damage), "battle cleanup removes damage stacks")
	_check(is_equal_approx(gun.get_fire_rate(), base_rate), "battle cleanup removes attack speed stacks")
	_check(is_equal_approx(gun.get_modified_attack_range(gun.attack_range), base_range), "battle cleanup removes range stacks")
	_check(is_equal_approx(miner.get_effective_ore_per_second(), base_mining), "battle cleanup removes mining stacks")

	var wave_effect := definition.effect_script.new() as GoblinWheelEffect
	wave_effect.configure(definition, ship)
	add_child(wave_effect)
	await get_tree().process_frame
	wave_effect._on_wave_completed(2, 10)
	_check(wave_effect.get_total_rolls_awarded() == 0, "wave two does not roll")
	wave_effect._on_wave_completed(3, 10)
	_check(wave_effect.get_total_rolls_awarded() == 1, "wave three awards exactly one buff without a HUD")
	wave_effect.cleanup()

	var panel := PANEL_SCRIPT.new() as GoblinWheelPanel
	add_child(panel)
	await get_tree().process_frame
	_panel_result = &""
	panel.spin_finished.connect(func(buff_id: StringName) -> void: _panel_result = buff_id)
	panel.start_spin(offered)
	await get_tree().process_frame
	_check(panel.visible and panel.mouse_filter == Control.MOUSE_FILTER_STOP and panel.selected_index == -1 and not get_tree().paused, "wheel waits for a player choice without pausing battle")
	_check(panel.choose_option(1), "player can click one of the three offered buffs")
	panel.finish_immediately()
	_check(_panel_result == StringName(offered[1]["id"]), "wheel lands on the player's selected offered buff")
	panel.queue_free()
	ship.queue_free()
	await get_tree().process_frame

	if failures.is_empty():
		print("GOBLIN_WHEEL_TEST: PASS")
	else:
		for failure in failures:
			push_error("GOBLIN_WHEEL_TEST: " + failure)
	get_tree().quit(1 if not failures.is_empty() else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
