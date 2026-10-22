extends Node2D

## Demon Prism: legendary, granted once by the Demon Lord, +100% attack range
## on the equipped weapon during battle. Runs against a throwaway save.
const TestSave := preload("res://Tests/TestSave.gd")
const BattleMainScript := preload("res://Scripts/Battle/BattleMain.gd")
const GUN := "res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn"
const LASER := "res://Scenes/Modules/Weapons/Laser/laser.tscn"
const FLAME := "res://Scenes/Modules/Weapons/Flamethrower/flamethrower.tscn"
var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, description: String) -> void:
	if not ok:
		failures.append(description)


func _run() -> void:
	TestSave.isolate("demon_prism_test")
	ShipLoadout.installed_modules.clear()
	ArtifactManager.reload_progress()
	ArtifactManager.set_equipment_changes_enabled(true)
	var definition := ArtifactManager.get_definition(&"demon_prism")
	check(definition != null, "demon prism registered")
	if definition != null:
		check(definition.rarity == "Legendary", "demon prism is legendary")
		check(not definition.mining_chest_reward, "not a chest reward")
		check(definition.is_compatible_with_module(&"flamethrower"), "fits flamethrower")
	check(not ArtifactManager.owns_artifact(&"demon_prism"), "not owned at start")
	var boss := load("res://Scenes/Enemies/demon_lord.tscn").instantiate() as DemonLord
	add_child(boss)
	await get_tree().process_frame
	boss._die()
	check(ArtifactManager.owns_artifact(&"demon_prism"), "demon lord grants prism")
	check(not ArtifactManager.grant_artifact(&"demon_prism"), "prism is unique")
	ShipLoadout.install_module(0, 0, GUN)
	ShipLoadout.install_module(0, 1, GUN)
	ResearchManager.progress.levels["weapon_damage.machine_gun"] = 10
	ResearchManager.progress.levels["weapon_damage.flamethrower"] = 10
	ResearchManager.progress.levels["weapon_damage.laser"] = 10
	check(ArtifactManager.equip_module_artifact(Vector2i(0, 0), &"demon_prism"), "equip prism")
	var ship := load("res://Scenes/Ship/ship.tscn").instantiate() as Ship
	add_child(ship)
	await get_tree().process_frame
	var prism_gun := ship.get_module_at(0, 0) as WeaponModule
	var plain_gun := ship.get_module_at(0, 1) as WeaponModule
	var base_range: float = prism_gun.get("attack_range")
	check(is_equal_approx(prism_gun.get_modified_attack_range(base_range), base_range), "no bonus before battle")
	ArtifactManager.attach_battle_effects(ship)
	check(is_equal_approx(prism_gun.get_modified_attack_range(base_range), base_range * 2.0), "prism doubles range")
	check(is_equal_approx(plain_gun.get_modified_attack_range(base_range), base_range), "other weapon unaffected")
	ArtifactManager.clear_battle_effects(ship)
	await get_tree().process_frame
	check(is_equal_approx(prism_gun.get_modified_attack_range(base_range), base_range), "cleanup removes bonus")
	ship.queue_free()
	await get_tree().process_frame
	# Flamethrower: the prism's range also grows each flame puff.
	ShipLoadout.install_module(0, 0, FLAME)
	check(ArtifactManager.equip_module_artifact(Vector2i(0, 0), &"demon_prism"), "equip prism on flamethrower")
	var ship2 := load("res://Scenes/Ship/ship.tscn").instantiate() as Ship
	add_child(ship2)
	await get_tree().process_frame
	var flame := ship2.get_module_at(0, 0) as Flamethrower
	check(flame != null, "flamethrower installed")
	if flame != null:
		ArtifactManager.attach_battle_effects(ship2)
		check(is_equal_approx(flame.get_flame_size_scale(), 2.0), "prism doubles flame puff size")
		ArtifactManager.clear_battle_effects(ship2)
	ship2.queue_free()
	await get_tree().process_frame
	# Laser: the prism's range also widens the beam.
	ShipLoadout.install_module(0, 0, LASER)
	check(ArtifactManager.equip_module_artifact(Vector2i(0, 0), &"demon_prism"), "equip prism on laser")
	var ship3 := load("res://Scenes/Ship/ship.tscn").instantiate() as Ship
	add_child(ship3)
	await get_tree().process_frame
	var laser := ship3.get_module_at(0, 0) as Laser
	check(laser != null, "laser installed")
	if laser != null:
		var width := laser.get_effective_beam_width()
		check(is_equal_approx(width, laser.beam_width), "plain beam width")
		ArtifactManager.attach_battle_effects(ship3)
		check(is_equal_approx(laser.get_effective_beam_width(), laser.beam_width * 11.0), "prism +100% range gives +1000% beam width")
		check(is_equal_approx(BattleMainScript.get_weapon_range(laser), laser.attack_range * 2.0), "range preview includes the prism")
		ArtifactManager.clear_battle_effects(ship3)
	ShipLoadout.installed_modules.clear()
	if failures.is_empty():
		print("DemonPrismTest PASS")
	else:
		for f in failures:
			push_error("DEMON_PRISM_TEST FAIL: " + f)
	get_tree().quit(1 if not failures.is_empty() else 0)
