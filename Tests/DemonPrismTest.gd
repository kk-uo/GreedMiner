extends Node2D

## Demon Prism: legendary, granted once by the Demon Lord, +100% projectile size
## on the equipped weapon during battle. Runs against a throwaway save.
const TestSave := preload("res://Tests/TestSave.gd")
const GUN := "res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn"
const FLAME := "res://Scenes/Modules/Weapons/Flamethrower/flamethrower.tscn"
const LASER := "res://Scenes/Modules/Weapons/Laser/laser.tscn"
const HEAVY_LASER := "res://Scenes/Modules/Weapons/Fusion/heavy_laser.tscn"
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
		check(definition.is_compatible_with_module(&"flamethrower"), "fits projectile weapons")
		check(definition.is_compatible_with_module(&"laser"), "fits laser beam weapons")
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
	check(ArtifactManager.equip_module_artifact(Vector2i(0, 0), &"demon_prism"), "equip prism")
	var ship := load("res://Scenes/Ship/ship.tscn").instantiate() as Ship
	add_child(ship)
	await get_tree().process_frame
	var prism_gun := ship.get_module_at(0, 0) as WeaponModule
	var plain_gun := ship.get_module_at(0, 1) as WeaponModule
	var base_range: float = prism_gun.get("attack_range")
	var base_projectile_range: float = prism_gun.get("projectile_range")
	check(is_equal_approx(prism_gun.get_modified_attack_range(base_range), base_range), "no bonus before battle")
	check(is_equal_approx(prism_gun.get_modified_projectile_range(base_projectile_range), base_projectile_range), "no projectile bonus before battle")
	ArtifactManager.attach_battle_effects(ship)
	check(is_equal_approx(prism_gun.get_modified_attack_range(base_range), base_range), "prism leaves targeting range unchanged")
	check(is_equal_approx(prism_gun.get_modified_projectile_range(base_projectile_range), base_projectile_range * 2.0), "prism independently doubles projectile range")
	check(is_equal_approx(plain_gun.get_modified_attack_range(base_range), base_range), "other weapon unaffected")
	check(is_equal_approx(plain_gun.get_modified_projectile_range(base_projectile_range), base_projectile_range), "other projectile range unaffected")
	ArtifactManager.clear_battle_effects(ship)
	await get_tree().process_frame
	check(is_equal_approx(prism_gun.get_modified_attack_range(base_range), base_range), "cleanup removes bonus")
	check(is_equal_approx(prism_gun.get_modified_projectile_range(base_projectile_range), base_projectile_range), "cleanup removes projectile bonus")
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
	# Beam width is both the displayed line width and its collision thickness.
	ResearchManager.progress.levels["weapon_damage.laser"] = 10
	ShipLoadout.install_module(0, 0, LASER)
	check(ArtifactManager.equip_module_artifact(Vector2i(0, 0), &"demon_prism"), "equip prism on Laser")
	var ship3 := load("res://Scenes/Ship/ship.tscn").instantiate() as Ship
	add_child(ship3)
	await get_tree().process_frame
	var laser := ship3.get_module_at(0, 0) as Laser
	check(laser != null, "Laser installed")
	if laser != null:
		check(is_equal_approx(laser.get_effective_beam_width(), 6.0), "Laser begins with a 6 px beam")
		ArtifactManager.attach_battle_effects(ship3)
		check(is_equal_approx(laser.get_effective_beam_width(), 12.0), "prism doubles Laser visual and collision width")
		laser._update_beam_length()
		check(is_equal_approx(laser._beam.width, 12.0), "Laser visual follows prism width")
		ArtifactManager.clear_battle_effects(ship3)
	ship3.queue_free()
	await get_tree().process_frame
	ResearchManager.progress.levels["weapon_damage.heavy_laser"] = 10
	ShipLoadout.install_module(0, 0, HEAVY_LASER)
	check(ArtifactManager.equip_module_artifact(Vector2i(0, 0), &"demon_prism"), "equip prism on Heavy Laser")
	var ship4 := load("res://Scenes/Ship/ship.tscn").instantiate() as Ship
	add_child(ship4)
	await get_tree().process_frame
	var heavy := ship4.get_module_at(0, 0) as FusionWeapon
	check(heavy != null, "Heavy Laser installed")
	if heavy != null:
		check(is_equal_approx(heavy.beam_width, 60.0), "Heavy Laser beam is ten times base Laser width")
		ArtifactManager.attach_battle_effects(ship4)
		check(is_equal_approx(heavy.get_modified_projectile_range(heavy.beam_width), 120.0), "prism doubles Heavy Laser collision width")
		heavy._update_beam()
		check(is_equal_approx(heavy._beam.width, 120.0), "Heavy Laser visual follows prism width")
		ArtifactManager.clear_battle_effects(ship4)
	ship4.queue_free()
	await get_tree().process_frame
	ShipLoadout.installed_modules.clear()
	if failures.is_empty():
		print("DemonPrismTest PASS")
	else:
		for f in failures:
			push_error("DEMON_PRISM_TEST FAIL: " + f)
	get_tree().quit(1 if not failures.is_empty() else 0)
