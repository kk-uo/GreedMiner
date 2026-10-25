extends Node

const BASE_SCENE := preload("res://Scenes/Base/base_main.tscn")
const TEST_SAVE := "user://greedminer_weapon_fusion_test.json"
const ENERGY := "res://Scenes/Modules/Energy/energy_module.tscn"
const MACHINE_GUN := "res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn"
const DWARF_CANNON := "res://Scenes/Modules/Weapons/DwarfCannon/dwarf_cannon.tscn"
const LASER := "res://Scenes/Modules/Weapons/Laser/laser.tscn"
const LASER_MACHINE_GUN := "res://Scenes/Modules/Weapons/Fusion/laser_machine_gun.tscn"

var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# Use a writable temporary directory when the normal user-data directory is
	# sandboxed; the fallback remains portable for other Godot test hosts.
	var temp_dir := OS.get_environment("TMPDIR")
	var test_save_path := temp_dir.path_join("greedminer_weapon_fusion_test.json") if not temp_dir.is_empty() else TEST_SAVE
	ProgressionStore.set_save_path_for_testing(test_save_path)
	ProgressionStore.reset_all_progress()
	ResearchManager.reload_progress()
	WeaponUnlockManager.completed_planet_ids[String(WeaponFusionRegistry.REQUIRED_PLANET)] = true
	for weapon_id in WeaponFusionRegistry.BASE_WEAPONS:
		var definition := ResearchManager.get_weapon_research_definition(weapon_id)
		_expect(definition != null, "research definition exists for %s" % weapon_id)
		if definition != null:
			ResearchManager.progress.levels[String(definition.research_id)] = 30
	_expect(WeaponFusionRegistry.is_unlocked(), "fusion unlock requires Graveyard clear and all weapon levels 30")
	_expect(is_equal_approx(WeaponFusionRegistry.FUSION_DURATION_SECONDS, 1.0), "fusion completes in one second")
	_expect(WeaponFusionRegistry.RECIPES.size() == 13, "all thirteen fusion recipes are registered")
	_expect(WeaponFusionRegistry.find_recipe(&"laser", &"laser").is_empty(), "Laser + Laser is not a Heavy Laser recipe")
	_expect(WeaponFusionRegistry.find_recipe(&"dwarf_cannon", &"laser").get("result_id", &"") == &"heavy_laser", "Dwarf Cannon + Laser creates Heavy Laser")
	var expected_power := {
		&"scatter_machine_gun": 3, &"knockback_machine_gun": 3,
		&"laser_machine_gun": 3, &"sawblade_machine_gun": 4,
		&"flame_machine_gun": 4, &"laser_chainsaw": 4,
		&"heavy_laser": 3, &"automatic_cannon": 3,
		&"siege_cannon": 3,
		&"knockback_cannon": 3, &"flame_cannon": 4, &"knockback_laser": 3,
		&"flame_laser": 4,
	}

	for recipe in WeaponFusionRegistry.RECIPES:
		_expect(is_equal_approx(float(recipe.get("duration", 0.0)), 1.0), "each fusion recipe uses the one-second timer")
		var ingredients: Array = recipe["ingredients"]
		_expect(not WeaponFusionRegistry.find_recipe(ingredients[0], ingredients[1]).is_empty(), "recipe resolves in authored order")
		_expect(not WeaponFusionRegistry.find_recipe(ingredients[1], ingredients[0]).is_empty(), "recipe resolves in reverse order")
		var scene := load(String(recipe["scene"])) as PackedScene
		_expect(scene != null, "%s scene loads" % recipe["result_id"])
		var research := ResearchManager.get_weapon_research_definition(recipe["result_id"])
		_expect(research != null, "%s has independent research" % recipe["result_id"])
		if research != null:
			_expect(research.category_id == ResearchManager.FUSION_WEAPON_CATEGORY_ID, "%s appears on the Fusion Weapons laboratory page" % recipe["result_id"])
			_expect(research.max_level == 30, "%s research reaches Level 30" % recipe["result_id"])
			_expect(ResearchManager.get_weapon_research_level(recipe["result_id"]) == 1, "%s research starts at Level 1" % recipe["result_id"])
		if scene != null:
			var module := scene.instantiate() as FusionWeapon
			_expect(module != null, "%s is a FusionWeapon" % recipe["result_id"])
			if module != null:
				_expect(module.weapon_type_id == recipe["result_id"], "%s uses its own research ID" % recipe["result_id"])
				_expect(module.get_power_consumption() == expected_power[recipe["result_id"]], "%s uses combined ingredient power plus one" % recipe["result_id"])
				_expect(int(ModuleCatalog.get_stats(recipe["result_id"]).get("power_cost", -1)) == expected_power[recipe["result_id"]], "%s catalog displays the updated power cost" % recipe["result_id"])
				module.free()

	var laser_machine_gun := ModuleCatalog.get_scene(&"laser_machine_gun").instantiate() as FusionWeapon
	_expect(laser_machine_gun.attack_kind == FusionWeapon.AttackKind.PROJECTILE, "Laser Machine Gun fires projectile-like laser bolts")
	_expect(is_equal_approx(laser_machine_gun.attack_range, 1500.0), "Laser Machine Gun range is 1500")
	_expect(is_equal_approx(laser_machine_gun.projectile_speed, 1000.0), "Laser Machine Gun projectile speed is 1000")
	_expect(laser_machine_gun.projectile_pierces_all_targets, "Laser Machine Gun laser bolts pierce all targets")
	_expect(laser_machine_gun.projectile_scene != null, "Laser Machine Gun has a projectile scene")
	laser_machine_gun.free()

	var heavy_laser := ModuleCatalog.get_scene(&"heavy_laser").instantiate() as FusionWeapon
	_expect(is_equal_approx(heavy_laser.projectile_range, 60.0), "Heavy Laser projectile range is ten times Laser width")
	_expect(is_equal_approx(heavy_laser.beam_width, 60.0), "Heavy Laser collision and visual beam width are 60 px")
	heavy_laser.free()

	var knockback_laser := ModuleCatalog.get_scene(&"knockback_laser").instantiate() as FusionWeapon
	_expect(knockback_laser.attack_kind == FusionWeapon.AttackKind.WAVE, "Knockback Laser fires a travelling wave")
	_expect(is_equal_approx(knockback_laser.basic_damage, 15.0), "Knockback Laser initial contact deals 15")
	_expect(is_equal_approx(knockback_laser.wave_damage_per_second, 1.0), "Knockback Laser subsequent damage is 1 per second")
	_expect(is_equal_approx(knockback_laser.projectile_range, 100.0), "Knockback Laser wave length is 100 px")
	_expect(is_equal_approx(knockback_laser.knockback_distance, 200.0), "Knockback Laser pushes 200 px")
	_expect(not WeaponFusionRegistry.find_recipe(&"laser", &"knockback_module").is_empty(), "Knockback Laser recipe works in reverse order")
	knockback_laser.free()

	var automatic_cannon := ModuleCatalog.get_scene(&"automatic_cannon").instantiate() as FusionWeapon
	_expect(is_equal_approx(automatic_cannon.basic_damage, 15.0), "Automatic Cannon base damage is reduced to 15")
	automatic_cannon.free()

	var siege_cannon := ModuleCatalog.get_scene(&"siege_cannon").instantiate() as FusionWeapon
	_expect(is_equal_approx(siege_cannon.basic_damage, 120.0), "Siege Cannon deals 4x Dwarf Cannon base damage")
	_expect(is_equal_approx(siege_cannon.attack_interval, 5.0), "Siege Cannon fires every 5 seconds")
	_expect(is_equal_approx(siege_cannon.attack_range, 1000.0), "Siege Cannon has 2x Dwarf Cannon range")
	siege_cannon.free()

	var scatter_research := ResearchManager.get_weapon_research_definition(&"scatter_machine_gun")
	if scatter_research != null:
		ResearchManager.progress.levels[String(scatter_research.research_id)] = 2
		var scatter := ModuleCatalog.get_scene(&"scatter_machine_gun").instantiate() as FusionWeapon
		_expect(is_equal_approx(scatter.get_damage(), 6.0), "fusion research applies its own 20% Level 2 damage bonus")
		_expect(ResearchManager.get_weapon_research_level(&"machine_gun") == 30, "fusion upgrade does not change ingredient research")
		scatter.free()

	ShipLoadout.installed_modules.clear()
	ShipLoadout.install_module(1, 1, ENERGY)
	ShipLoadout.install_module(0, 0, MACHINE_GUN)
	ShipLoadout.install_module(0, 1, LASER)
	var base := BASE_SCENE.instantiate()
	add_child(base)
	await get_tree().process_frame
	base._enter_assembly()
	await get_tree().create_timer(0.8).timeout
	base._begin_ship_drag(Vector2i(0, 0))
	var dragged_module: ShipModule = base.ship.get_module_at(0, 0)
	var target_local: Vector2 = base.ship.get_cell_center(0, 1)
	base._update_ship_drag(base.ship.installed_modules.to_global(target_local), Vector2.ZERO)
	_expect(base._fusion_in_progress, "fusion progress remains active during the timer")
	_expect(dragged_module.position.distance_to(target_local) < 0.5, "the actual dragged turret remains over the target during fusion")
	await get_tree().create_timer(WeaponFusionRegistry.FUSION_DURATION_SECONDS + 0.2).timeout
	_expect(not base._fusion_in_progress, "fusion timer completes")
	_expect(not ShipLoadout.has_module(0, 0), "source cell is consumed")
	_expect(ShipLoadout.get_module(0, 1) == LASER_MACHINE_GUN, "target cell stores the fusion result")
	_expect(base.ship.get_module_at(0, 1) is FusionWeapon, "runtime target is the fusion weapon")
	_expect(base.ship.total_power_consumption == 3, "fusion result adds one power to the ship profile")
	_expect(base.ship.remove_module(0, 1), "first fusion result can be removed")
	var cannon_scene := load(DWARF_CANNON) as PackedScene
	var laser_scene := load(LASER) as PackedScene
	_expect(base.ship.install_module(cannon_scene, Ship.ModuleType.Weapon, 0, 0), "Dwarf Cannon installs")
	_expect(base.ship.install_module(laser_scene, Ship.ModuleType.Weapon, 0, 1), "Laser installs")
	base._begin_ship_drag(Vector2i(0, 0))
	base._update_ship_drag(base.ship.installed_modules.to_global(target_local), Vector2.ZERO)
	_expect(base._fusion_in_progress, "Dwarf Cannon + Laser overlap starts fusion")
	await get_tree().create_timer(WeaponFusionRegistry.FUSION_DURATION_SECONDS + 0.2).timeout
	_expect(not ShipLoadout.has_module(0, 0), "Dwarf Cannon + Laser consumes its source")
	_expect(ShipLoadout.get_module(0, 1) == "res://Scenes/Modules/Weapons/Fusion/heavy_laser.tscn", "Dwarf Cannon + Laser installs Heavy Laser")
	_expect(base.ship.total_power_consumption == 3, "Heavy Laser consumes three power after fusion")
	_expect(base.ship.remove_module(0, 1), "Heavy Laser can be removed for the power-limit check")
	var machine_gun_scene := load(MACHINE_GUN) as PackedScene
	_expect(base.ship.install_module(machine_gun_scene, Ship.ModuleType.Weapon, 0, 0), "first Machine Gun installs for power-limit check")
	_expect(base.ship.install_module(laser_scene, Ship.ModuleType.Weapon, 0, 1), "Laser installs for power-limit check")
	_expect(base.ship.install_module(machine_gun_scene, Ship.ModuleType.Weapon, 0, 2), "second Machine Gun installs for power-limit check")
	_expect(base.ship.install_module(machine_gun_scene, Ship.ModuleType.Weapon, 2, 0), "third Machine Gun fills the four-power capacity")
	_expect(not base.ship.fuse_modules(Vector2i(0, 0), Vector2i(0, 1), ModuleCatalog.get_scene(&"laser_machine_gun")), "fusion is rejected when its extra power exceeds capacity")
	_expect(ShipLoadout.get_module(0, 0) == MACHINE_GUN and ShipLoadout.get_module(0, 1) == LASER, "rejected fusion preserves both ingredients")
	_expect(base.ship.total_power_consumption == 4, "rejected fusion preserves the original power profile")

	base.queue_free()
	ShipLoadout.installed_modules.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save_path))
	await get_tree().process_frame
	if failures.is_empty():
		print("WEAPON_FUSION_SYSTEM_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("WEAPON_FUSION_SYSTEM_TEST: " + failure)
		print("WEAPON_FUSION_SYSTEM_TEST: FAIL (%d failures)" % failures.size())
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
