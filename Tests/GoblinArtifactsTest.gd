extends Node2D

## Uses an isolated save to test rewards, location filtering and battle effects.
const TEST_SAVE := "user://greedminer_goblin_artifacts_test.json"
const GUN := "res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn"
var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, description: String) -> void:
	if not ok:
		failures.append(description)


func _run() -> void:
	ProgressionStore.set_save_path_for_testing(TEST_SAVE)
	ProgressionStore.reset_all_progress()
	ShipLoadout.load_saved()
	ArtifactManager.reload_progress()
	ArtifactManager.set_equipment_changes_enabled(true)
	var rocky_pool := ArtifactManager.get_unowned_mining_chest_artifacts(&"rocky_planet")
	var verdant_pool := ArtifactManager.get_unowned_mining_chest_artifacts(&"goblin_planet")
	check(rocky_pool.any(func(d): return d.artifact_id == &"angry_stone"), "Angry Stone available on Rocky")
	check(not verdant_pool.any(func(d): return d.artifact_id == &"angry_stone"), "Angry Stone absent on Verdant")
	for planet in [&"frozen_planet", &"volcanic_planet", &"graveyard_planet"]:
		check(not ArtifactManager.get_unowned_mining_chest_artifacts(planet).any(func(d): return d.artifact_id == &"angry_stone"), "Angry Stone absent on %s" % planet)
	check(ArtifactManager.get_definition(&"angry_stone").source_planet_id == &"rocky_planet", "Angry Stone listed under Rocky")
	check(not rocky_pool.any(func(d): return d.artifact_id == &"goblin_flag"), "flag absent outside Verdant")
	check(verdant_pool.any(func(d): return d.artifact_id == &"goblin_flag"), "flag available on Verdant")
	check(ArtifactManager.grant_artifact(&"goblin_flag"), "grant flag")
	check(not ArtifactManager.grant_artifact(&"goblin_flag"), "flag is unique")
	check(not ArtifactManager.get_unowned_mining_chest_artifacts(&"goblin_planet").any(func(d): return d.artifact_id == &"goblin_flag"), "owned flag excluded")
	var boss := load("res://Scenes/Enemies/goblin_giant_chariot.tscn").instantiate() as GoblinGiantChariot
	boss.death_spawn_count = 0
	add_child(boss)
	await get_tree().process_frame
	boss.take_damage(100000.0)
	check(ArtifactManager.owns_artifact(&"goblin_horn"), "boss grants horn")
	check(not ArtifactManager.grant_artifact(&"goblin_horn"), "horn is unique")
	ShipLoadout.install_module(0, 0, GUN)
	ShipLoadout.install_module(0, 1, GUN)
	ResearchManager.progress.levels["weapon_damage.machine_gun"] = 10
	check(ArtifactManager.equip_module_artifact(Vector2i(0, 0), &"goblin_horn"), "equip horn")
	check(ArtifactManager.equip_module_artifact(Vector2i(0, 1), &"goblin_flag"), "equip flag")
	ProgressionStore.reload_from_disk()
	ArtifactManager.reload_progress()
	check(ArtifactManager.get_module_artifact(Vector2i(0, 0)) == &"goblin_horn", "horn equipment persists")
	check(ArtifactManager.get_module_artifact(Vector2i(0, 1)) == &"goblin_flag", "flag equipment persists")
	var ship := load("res://Scenes/Ship/ship.tscn").instantiate() as Ship
	add_child(ship)
	await get_tree().process_frame
	var horn_gun := ship.get_module_at(0, 0) as WeaponModule
	var flag_gun := ship.get_module_at(0, 1) as WeaponModule
	var horn_base := horn_gun.get_fire_rate()
	var flag_base := flag_gun.get_fire_rate()
	ArtifactManager.attach_battle_effects(ship)
	check(is_equal_approx(flag_gun.get_fire_rate(), flag_base * 1.25), "flag adds 25% to equipped weapon")
	check(is_equal_approx(horn_gun.get_fire_rate(), horn_base), "horn starts with no bonus")
	var enemy := load("res://Scenes/Enemies/little_rock.tscn").instantiate() as BasicEnemy
	enemy.max_health = 5000.0
	add_child(enemy)
	await get_tree().process_frame
	enemy.take_damage(1999.0, false, true, horn_gun)
	check(is_equal_approx(horn_gun.get_fire_rate(), horn_base), "1999 actual damage gives no stack")
	enemy.take_damage(1.0, false, false)
	enemy.take_damage(1.0, false, true, flag_gun)
	check(is_equal_approx(ArtifactManager.get_weapon_battle_activity(horn_gun), 1999.0), "other weapon and enemy damage excluded")
	ship.current_hp = ship.max_hp - 1.0
	ship.heal(100.0)
	check(is_equal_approx(ArtifactManager.get_weapon_battle_activity(horn_gun), 1999.0), "unattributed healing excluded")
	ship.current_hp = ship.max_hp - 1.0
	ship.heal(100.0, horn_gun)
	check(is_equal_approx(ArtifactManager.get_weapon_battle_activity(horn_gun), 2000.0), "weapon-attributed actual healing counts")
	check(is_equal_approx(horn_gun.get_fire_rate(), horn_base * 1.01), "2000 combined activity gives 1%")
	enemy.take_damage(10000.0, false, true, horn_gun)
	check(is_equal_approx(ArtifactManager.get_weapon_battle_activity(horn_gun), 4999.0), "overkill and other damage excluded")
	check(is_equal_approx(horn_gun.get_fire_rate(), horn_base * 1.02), "multiple stacks accumulate")
	check(is_equal_approx(flag_gun.get_fire_rate(), flag_base * 1.25), "horn does not affect flag weapon")
	ArtifactManager.clear_battle_effects(ship)
	check(is_equal_approx(horn_gun.get_fire_rate(), horn_base), "cleanup removes bonus")
	ArtifactManager.attach_battle_effects(ship)
	check(is_zero_approx(ArtifactManager.get_weapon_battle_activity(horn_gun)), "new battle resets total")
	check(is_equal_approx(horn_gun.get_fire_rate(), horn_base), "new battle resets horn stacks")
	var projectile_target := load("res://Scenes/Enemies/little_rock.tscn").instantiate() as BasicEnemy
	projectile_target.max_health = 100.0
	add_child(projectile_target)
	var projectile := load("res://Scenes/Modules/Weapons/MachineGun/machine_gun_projectile.tscn").instantiate() as MachineGunProjectile
	add_child(projectile)
	projectile.source_weapon = horn_gun
	projectile.damage = 10.0
	projectile._on_area_entered(projectile_target)
	check(is_equal_approx(ArtifactManager.get_weapon_battle_activity(horn_gun), 10.0), "projectile damage is attributed to its source weapon")
	ArtifactManager.clear_battle_effects(ship)
	if failures.is_empty():
		print("GOBLIN_ARTIFACTS_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("GOBLIN_ARTIFACTS_TEST: FAIL")
		get_tree().quit(1)
