extends Node2D

const GUN := "res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn"
const MINER := "res://Scenes/Modules/Mining/mining_module.tscn"
var failures: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _run() -> void:
	ProgressionStore.set_save_path_for_testing("user://angry_stone_test.json")
	ProgressionStore.reset_all_progress()
	ShipLoadout.load_saved()
	ArtifactManager.reload_progress()
	ArtifactManager.set_equipment_changes_enabled(true)
	ResourceManager.current_expedition_planet_id = &"rocky_planet"
	check(ArtifactManager.get_unowned_mining_chest_artifacts().size() == 1, "chest pool")
	check(ArtifactManager.get_definition(&"angry_stone").rarity == "Common", "rarity")
	var conf := MiningQteConfig.new()
	check(is_equal_approx(conf.salvage_artifact_chance, 0.7), "70 percent artifact chance")
	var miner := load(MINER).instantiate() as MiningModule
	add_child(miner)
	miner.mining_rate = 2.5
	check(is_equal_approx(MiningQteManager.calculate_reward(miner, conf), 250.0), "100 x mining speed")
	var manager := MiningQteManager.new()
	manager.auto_trigger = false
	add_child(manager)
	conf.salvage_artifact_chance = 0.0
	var ore_chest := SalvageDiscoveryEvent.new()
	add_child(ore_chest)
	ore_chest.begin(manager, miner, conf)
	ore_chest._set_phase(SalvageDiscoveryEvent.Phase.WAIT)
	var starting_ore := ResourceManager.mission_ore
	ore_chest.open()
	check(is_equal_approx(ResourceManager.mission_ore - starting_ore, 250.0), "ore branch pays 100 x rate")
	check(not ArtifactManager.owns_artifact(&"angry_stone"), "ore branch does not grant artifact")
	conf.salvage_artifact_chance = 1.0
	var chest := SalvageDiscoveryEvent.new()
	add_child(chest)
	chest.begin(manager, miner, conf)
	chest._set_phase(SalvageDiscoveryEvent.Phase.WAIT)
	var ore_before := ResourceManager.mission_ore
	chest.open()
	check(ArtifactManager.owns_artifact(&"angry_stone"), "chest grants artifact")
	check(ArtifactManager.is_stall_unlocked() and ArtifactManager.tutorial_pending, "stall and guide")
	check(ResourceManager.mission_ore == ore_before, "artifact chest does not also pay ore")
	check(not ArtifactManager.grant_artifact(&"angry_stone"), "no duplicate")
	check(ArtifactManager.get_unowned_mining_chest_artifacts().is_empty(), "no eligible artifact after collection")
	var chest2 := SalvageDiscoveryEvent.new()
	add_child(chest2)
	chest2.begin(manager, miner, conf)
	chest2._set_phase(SalvageDiscoveryEvent.Phase.WAIT)
	chest2.open()
	check(is_equal_approx(ResourceManager.mission_ore - ore_before, 250.0), "empty pool returns ore")
	ShipLoadout.install_module(0, 0, GUN)
	ResearchManager.progress.levels["ship_magic_slot_1"] = 1
	check(not ArtifactManager.equip_ship_artifact(0, &"angry_stone"), "ship incompatible")
	check(ArtifactManager.equip_module_artifact(Vector2i(0, 0), &"angry_stone"), "weapon equip")
	ArtifactManager.reload_progress()
	check(ArtifactManager.get_module_artifact(Vector2i(0, 0)) == &"angry_stone", "equipment persists")
	ArtifactManager.set_equipment_changes_enabled(false)
	check(not ArtifactManager.unequip_module_artifact(Vector2i(0, 0)), "battle equipment guard")
	ArtifactManager.set_equipment_changes_enabled(true)
	var ship := load("res://Scenes/Ship/ship.tscn").instantiate() as Ship
	add_child(ship)
	await get_tree().process_frame
	var gun := ship.get_module_at(0, 0) as WeaponModule
	gun.assembly_mode = false
	ArtifactManager.attach_battle_effects(ship)
	var target := load("res://Scenes/Enemies/little_rock.tscn").instantiate() as BasicEnemy
	var near := load("res://Scenes/Enemies/little_rock.tscn").instantiate() as BasicEnemy
	var far := load("res://Scenes/Enemies/little_rock.tscn").instantiate() as BasicEnemy
	target.max_health = 200.0
	add_child(target)
	add_child(near)
	add_child(far)
	target.global_position = Vector2(500, 500)
	near.global_position = Vector2(525, 500)
	far.global_position = Vector2(700, 500)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var start := near.get_current_health()
	for i in range(3):
		var projectile := load("res://Scenes/Modules/Weapons/MachineGun/machine_gun_projectile.tscn").instantiate() as MachineGunProjectile
		add_child(projectile)
		projectile.damage = 10.0
		projectile.source_weapon = gun
		projectile._on_area_entered(target)
		if i < 2:
			check(is_equal_approx(near.get_current_health(), start), "first two hits do not splash")
	check(is_equal_approx(near.get_current_health(), start - 5.0), "third hit splash")
	check(is_equal_approx(far.get_current_health(), far.max_health), "distant enemy untouched")
	var old_effect := ship.get_node("MagicArtifactEffects").get_child(0) as AngryStoneEffect
	check(old_effect.hit_count == 3, "splash does not count or chain")
	ArtifactManager.clear_battle_effects(ship)
	ArtifactManager.attach_battle_effects(ship)
	var effect := ship.get_node("MagicArtifactEffects").get_child(0) as AngryStoneEffect
	check(effect != null and effect.hit_count == 0, "battle reset counter")
	ShipLoadout.remove_module(0, 0)
	check(ArtifactManager.get_module_artifact(Vector2i(0, 0)).is_empty(), "removing module clears slot")
	check(ArtifactManager.owns_artifact(&"angry_stone"), "removing module preserves ownership")
	if failures.is_empty():
		print("ANGRY_STONE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("ANGRY_STONE_TEST: FAIL")
		get_tree().quit(1)
