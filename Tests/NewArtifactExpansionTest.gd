extends Node

## Covers planet chest pools and runtime effects for Goblin Scope and True Ice.
const SAVE := preload("res://Tests/TestSave.gd")
const GUN := "res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn"
const SHIP := preload("res://Scenes/Ship/ship.tscn")
const ENEMY := preload("res://Scenes/Enemies/little_rock.tscn")

var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SAVE.isolate("new_artifact_expansion")
	ArtifactManager.reload_progress()
	ArtifactManager.set_equipment_changes_enabled(true)
	ShipLoadout.installed_modules.clear()
	ShipLoadout.install_module(0, 0, GUN)
	ResearchManager.progress.levels["weapon_damage.machine_gun"] = 30

	var scope := ArtifactManager.get_definition(&"goblin_scope")
	var ice := ArtifactManager.get_definition(&"true_ice")
	var prism := ArtifactManager.get_definition(&"demon_prism")
	var eyeball := ArtifactManager.get_definition(&"snow_monster_eyeball")
	_check(scope != null and scope.rarity == "Common", "Goblin Scope is registered as Common")
	_check(ice != null and ice.rarity == "Rare", "True Ice is registered as Rare")
	_check(prism != null and prism.rarity == "Legendary", "Demon Prism remains Legendary")
	_check(eyeball != null and eyeball.rarity == "Epic", "Snow Monster Eyeball is registered as Epic")
	_check(eyeball != null and eyeball.equip_target == MagicArtifactDefinition.EquipTarget.MODULE, "Snow Monster Eyeball equips on a turret")
	_check(eyeball != null and eyeball.is_compatible_with_module(&"machine_gun"), "Snow Monster Eyeball supports weapon modules")
	_check(scope in ArtifactManager.get_unowned_mining_chest_artifacts(&"goblin_planet"), "Goblin Scope is in Verdant chest pool")
	_check(scope not in ArtifactManager.get_unowned_mining_chest_artifacts(&"frozen_planet"), "Goblin Scope is excluded from Frozen chest pool")
	_check(ice in ArtifactManager.get_unowned_mining_chest_artifacts(&"frozen_planet"), "True Ice is in Frozen chest pool")
	_check(ice not in ArtifactManager.get_unowned_mining_chest_artifacts(&"goblin_planet"), "True Ice is excluded from Verdant chest pool")
	_check(eyeball in ArtifactManager.get_unowned_mining_chest_artifacts(&"frozen_planet"), "Snow Monster Eyeball is in Frozen chest pool")
	_check(eyeball not in ArtifactManager.get_unowned_mining_chest_artifacts(&"goblin_planet"), "Snow Monster Eyeball is excluded from Verdant chest pool")

	_check(ArtifactManager.grant_artifact(&"goblin_scope"), "Goblin Scope grants once")
	_check(not ArtifactManager.grant_artifact(&"goblin_scope"), "Goblin Scope cannot duplicate")
	_check(scope not in ArtifactManager.get_unowned_mining_chest_artifacts(&"goblin_planet"), "owned scope leaves chest pool")
	_check(ArtifactManager.equip_module_artifact(Vector2i.ZERO, &"goblin_scope", 0), "equip Goblin Scope")
	var ship := SHIP.instantiate() as Ship
	add_child(ship)
	await get_tree().process_frame
	var gun := ship.get_module_at(0, 0) as WeaponModule
	var base_range := float(gun.get("attack_range"))
	var base_projectile_size := float(gun.get("projectile_range"))
	ArtifactManager.attach_battle_effects(ship)
	_check(is_equal_approx(gun.get_modified_attack_range(base_range), base_range + 25.0), "Goblin Scope adds exactly 25 targeting range")
	_check(is_equal_approx(gun.get_modified_projectile_range(base_projectile_size), base_projectile_size), "Goblin Scope does not resize projectiles")
	ArtifactManager.clear_battle_effects(ship)
	ship.queue_free()
	await get_tree().process_frame

	_check(ArtifactManager.grant_artifact(&"true_ice"), "True Ice grants once")
	_check(not ArtifactManager.grant_artifact(&"true_ice"), "True Ice cannot duplicate")
	_check(ArtifactManager.equip_module_artifact(Vector2i.ZERO, &"true_ice", 0), "equip True Ice")
	var ice_ship := SHIP.instantiate() as Ship
	add_child(ice_ship)
	await get_tree().process_frame
	var ice_gun := ice_ship.get_module_at(0, 0) as WeaponModule
	ArtifactManager.attach_battle_effects(ice_ship)
	var regular := ENEMY.instantiate() as BasicEnemy
	regular.move_speed = 100.0
	add_child(regular)
	var boss := ENEMY.instantiate() as BasicEnemy
	boss.move_speed = 100.0
	boss.enemy_tier = BasicEnemy.EnemyTier.BOSS
	add_child(boss)
	await get_tree().process_frame
	ice_gun.projectile_hit.emit(regular, 1.0)
	ice_gun.projectile_hit.emit(boss, 1.0)
	_check(is_equal_approx(regular.get_effective_move_speed(), 70.0), "True Ice slows regular enemies by 30%")
	_check(is_equal_approx(boss.get_effective_move_speed(), 85.0), "True Ice slows bosses by 15%")
	regular._clear_artifact_projectile_slow()
	boss._clear_artifact_projectile_slow()
	_check(is_equal_approx(regular.get_effective_move_speed(), 100.0), "regular slow expires")
	_check(is_equal_approx(boss.get_effective_move_speed(), 100.0), "boss slow expires")
	ArtifactManager.clear_battle_effects(ice_ship)
	ice_ship.queue_free()
	await get_tree().process_frame

	_check(ArtifactManager.grant_artifact(&"snow_monster_eyeball"), "Snow Monster Eyeball grants once")
	_check(not ArtifactManager.grant_artifact(&"snow_monster_eyeball"), "Snow Monster Eyeball cannot duplicate")
	_check(ArtifactManager.equip_module_artifact(Vector2i.ZERO, &"snow_monster_eyeball", 1), "equip Snow Monster Eyeball on one turret")
	var eyeball_ship := SHIP.instantiate() as Ship
	add_child(eyeball_ship)
	await get_tree().process_frame
	var eyeball_gun := eyeball_ship.get_module_at(0, 0) as WeaponModule
	var eyeball_base_range := float(eyeball_gun.get("attack_range"))
	var eyeball_base_damage := eyeball_gun.get_damage()
	ArtifactManager.attach_battle_effects(eyeball_ship)
	_check(is_equal_approx(eyeball_gun.get_modified_attack_range(eyeball_base_range), eyeball_base_range * 2.0), "Snow Monster Eyeball doubles its equipped turret targeting range")
	_check(is_equal_approx(eyeball_gun.get_damage(), eyeball_base_damage * 0.75), "Snow Monster Eyeball reduces its equipped turret final damage by 25%")
	ArtifactManager.clear_battle_effects(eyeball_ship)
	ArtifactManager.unequip_module_artifact(Vector2i.ZERO, 1)
	eyeball_ship.queue_free()
	await get_tree().process_frame

	ShipLoadout.installed_modules.clear()
	if failures.is_empty():
		print("NEW_ARTIFACT_EXPANSION_TEST: PASS")
	else:
		for failure in failures:
			push_error("NEW_ARTIFACT_EXPANSION_TEST: " + failure)
	get_tree().quit(1 if not failures.is_empty() else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
