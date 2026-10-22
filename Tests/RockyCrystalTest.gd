extends Node

const TestSave := preload("res://Tests/TestSave.gd")
const BATTLE := preload("res://Scenes/Battle/BattleMain.tscn")
const CANNON := "res://Scenes/Modules/Weapons/DwarfCannon/dwarf_cannon.tscn"
var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


func _run() -> void:
	TestSave.isolate("rocky_crystals")
	ResourceManager.start_new_mission()
	var battle := BATTLE.instantiate()
	battle.get_node("WaveManager").auto_start = false
	var field := battle.get_node("Battlefield") as Battlefield
	check(is_equal_approx(field.red_crystal_chance, 0.01), "red crystal chance defaults to one percent")
	field.map_seed = 12345
	field.red_crystal_chance = 1.0
	add_child(battle)
	await get_tree().process_frame
	var crystals := field.get_interactables_root().get_node("RockyCrystals")
	check(crystals.get_child_count() > 0, "rocky crystals generated")
	if crystals.get_child_count() > 0:
		var crystal := crystals.get_child(crystals.get_child_count() - 1) as Node2D
		var position := crystal.global_position
		check(crystal.get("is_red"), "forced red spawn")
		check(crystal.call("can_be_mined"), "red crystal can be mined by dwarves")
		check(field.try_click_crystal(position), "crystal can be clicked")
		check(crystal.get("_shake") != null, "click starts shake")
		for i in range(20):
			crystal.call("register_click")
		check(not crystal.is_queued_for_deletion(), "repeated clicks do not break red crystal")
		check(ResourceManager.mission_ore == 0.0, "clicking does not award ore")
		check(not ArtifactManager.owns_artifact(&"red_crystal"), "clicking does not grant artifact")
		check(battle.get_node("Enemies").get_child_count() == 0, "clicking does not spawn a golem")
	field.red_crystal_chance = 0.0
	field.generate(12345)
	crystals = field.get_interactables_root().get_node("RockyCrystals")
	for seed_value in [1, 42, 12345, 98765]:
		field.generate(seed_value)
		check(field._deposits.size() >= 2, "Rocky seed %d has at least two crystal deposits" % seed_value)
	field.generate(12345)
	crystals = field.get_interactables_root().get_node("RockyCrystals")
	if crystals.get_child_count() > 0:
		var ordinary := crystals.get_child(0)
		check(not ordinary.get("is_red"), "ordinary crystal generated")
		for i in range(10):
			ordinary.call("register_click")
		check(not ordinary.is_queued_for_deletion(), "repeated clicks do not break ordinary crystal")
		check(ResourceManager.mission_ore == 0.0, "ordinary clicks do not grant ore")
		check(battle.get_node("Enemies").get_child_count() == 0, "ordinary clicks do not spawn a golem")
	await get_tree().process_frame
	var popup_amounts: Array[float] = []
	for node in battle.get_children():
		if node is RewardPopup:
			popup_amounts.append((node as RewardPopup).amount)
	check(popup_amounts.is_empty(), "clicking does not display an ore reward")
	field.planet_theme = &"frozen"
	field.generate(12345)
	# Other planets get their own ore deposits (Battlefield.PLANET_ORES), never Rocky crystals.
	var non_rocky_crystals := 0
	for node in field.get_interactables_root().get_node("RockyCrystals").get_children():
		if node.get("ore_kind") == &"":
			non_rocky_crystals += 1
	check(non_rocky_crystals == 0, "other planets unaffected")
	var definition := ArtifactManager.get_definition(&"red_crystal")
	check(definition != null and definition.rarity == "Epic", "epic definition registered")
	check(definition.is_compatible_with_module(&"dwarf_cannon"), "cannon compatible")
	check(definition.is_compatible_with_module(&"knockback_module"), "knockback compatible")
	check(not definition.is_compatible_with_module(&"machine_gun"), "non-explosive weapon incompatible")
	check(not definition.mining_chest_reward, "not in chest pool")
	var cannon := load(CANNON).instantiate() as WeaponModule
	cannon.assembly_mode = true
	add_child(cannon)
	var effect := definition.effect_script.new() as MagicArtifactEffect
	effect.configure(definition, null)
	effect.call("configure_module", cannon)
	add_child(effect)
	check(is_equal_approx(cannon.get_modified_explosion_damage(20.0), 30.0), "explosion damage increased by 50 percent")
	var target := load("res://Scenes/Enemies/little_rock.tscn").instantiate() as BasicEnemy
	target.max_health = 100.0
	add_child(target)
	target.global_position = Vector2(5000, 5000)
	var projectile := load("res://Scenes/Modules/Weapons/DwarfCannon/dwarf_cannon_projectile.tscn").instantiate() as DwarfCannonProjectile
	add_child(projectile)
	projectile.global_position = target.global_position
	projectile.damage = cannon.get_modified_explosion_damage(20.0)
	projectile.source_weapon = cannon
	await get_tree().physics_frame
	await get_tree().physics_frame
	projectile._explode()
	check(is_equal_approx(target.get_current_health(), 70.0), "actual explosion deals boosted damage")
	effect.cleanup()
	check(is_equal_approx(cannon.get_modified_explosion_damage(20.0), 20.0), "effect cleanup restores damage")
	ArtifactManager.set_equipment_changes_enabled(true)
	check(ArtifactManager.grant_artifact(&"red_crystal"), "grant artifact directly to test existing effects")
	WeaponUnlockManager.unlock_all_configured_weapons()
	ShipLoadout.install_module(0, 0, "res://Scenes/Modules/Shield/knockback_module.tscn")
	ResearchManager.progress.levels["shield_power.knockback_module"] = 10
	check(ArtifactManager.equip_module_artifact(Vector2i(0, 0), &"red_crystal"), "equip red crystal on knockback")
	ArtifactManager.reload_progress()
	check(ArtifactManager.get_module_artifact(Vector2i(0, 0)) == &"red_crystal", "knockback artifact persists")
	var test_ship := load("res://Scenes/Ship/ship.tscn").instantiate() as Ship
	add_child(test_ship)
	await get_tree().process_frame
	var knockback := test_ship.get_module_at(0, 0) as KnockbackModule
	check(knockback != null, "knockback restored on ship")
	if knockback != null:
		var researched_damage := knockback.get_effective_damage()
		var artifact_damage := researched_damage * 1.5
		ArtifactManager.attach_battle_effects(test_ship)
		check(is_equal_approx(knockback.get_effective_damage(), artifact_damage), "equipped knockback damage boosted by 50 percent")
		check(is_equal_approx(knockback.get_effective_splash_radius(), 64.0), "artifact does not change splash radius")
		var victim := load("res://Scenes/Enemies/little_rock.tscn").instantiate() as BasicEnemy
		victim.max_health = 100.0
		add_child(victim)
		victim.global_position = Vector2(6000, 6000)
		await get_tree().physics_frame
		knockback._activate(victim, test_ship)
		check(is_equal_approx(victim.get_current_health(), maxf(100.0 - artifact_damage, 0.0)), "knockback shockwave deals boosted damage")
		ArtifactManager.clear_battle_effects(test_ship)
		check(is_equal_approx(knockback.get_effective_damage(), researched_damage), "knockback effect cleanup restores damage")
	if failures.is_empty():
		print("ROCKY_CRYSTAL_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("ROCKY_CRYSTAL_TEST: " + failure)
		get_tree().quit(1)
