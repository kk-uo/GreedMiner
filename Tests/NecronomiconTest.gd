extends Node2D

const SAVE := preload("res://Tests/TestSave.gd")
const SHIP_SCENE := preload("res://Scenes/Ship/ship.tscn")
const GUN := "res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn"
const ENEMY := preload("res://Scenes/Enemies/little_rock.tscn")
const FRANK := preload("res://Scenes/Enemies/giant_frank.tscn")

var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SAVE.isolate("necronomicon")
	ArtifactManager.reload_progress()
	ArtifactManager.set_equipment_changes_enabled(true)
	var definition := ArtifactManager.get_definition(&"necronomicon")
	_check(definition != null and definition.rarity == "Legendary", "Necronomicon is registered as Legendary")
	_check(definition != null and not definition.mining_chest_reward, "Necronomicon is not in chest pools")
	_check(not ArtifactManager.owns_artifact(&"necronomicon"), "not owned before boss final death")
	var frank := FRANK.instantiate() as GiantFrank
	add_child(frank)
	await get_tree().process_frame
	frank._die()
	_check(not ArtifactManager.owns_artifact(&"necronomicon"), "first Frank collapse does not grant artifact")
	frank.phase = GiantFrank.Phase.ENRAGED
	frank._die()
	_check(ArtifactManager.owns_artifact(&"necronomicon"), "Frank final death grants artifact")
	_check(not ArtifactManager.grant_artifact(&"necronomicon"), "artifact remains globally unique")

	ShipLoadout.installed_modules.clear()
	ShipLoadout.install_module(0, 0, GUN)
	ResearchManager.progress.levels["weapon_damage.machine_gun"] = 10
	_check(ArtifactManager.equip_module_artifact(Vector2i.ZERO, &"necronomicon"), "equip on turret")
	var ship := SHIP_SCENE.instantiate() as Ship
	add_child(ship)
	await get_tree().process_frame
	var gun := ship.get_module_at(0, 0) as WeaponModule
	ArtifactManager.attach_battle_effects(ship)

	var victim := ENEMY.instantiate() as BasicEnemy
	victim.max_health = 90.0
	var fragile := ENEMY.instantiate() as BasicEnemy
	fragile.max_health = 20.0
	var witness := ENEMY.instantiate() as BasicEnemy
	witness.max_health = 100.0
	add_child(victim)
	add_child(fragile)
	add_child(witness)
	victim.global_position = Vector2(500.0, 500.0)
	fragile.global_position = Vector2(520.0, 500.0)
	witness.global_position = Vector2(540.0, 500.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	victim.take_damage(90.0, false, true, gun)
	_check(fragile.is_dying(), "33% max-health burst defeats a nearby fragile enemy")
	_check(is_equal_approx(witness.get_current_health(), 70.3), "nearby enemy takes exactly 33% of defeated max health")
	_check(not witness.is_dying(), "necromancy damage does not recursively trigger another burst")

	ArtifactManager.clear_battle_effects(ship)
	ShipLoadout.installed_modules.clear()
	if failures.is_empty():
		print("NECRONOMICON_TEST: PASS")
	else:
		for failure in failures:
			push_error("NECRONOMICON_TEST: " + failure)
	get_tree().quit(1 if not failures.is_empty() else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
