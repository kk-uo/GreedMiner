extends Node

const WEAPON := preload("res://Scenes/Modules/Weapons/Fusion/flame_laser.tscn")
const ENEMY := preload("res://Scenes/Enemies/little_rock.tscn")
const ANCIENT_DRAGON := preload("res://Scenes/Enemies/DragonNest/ancient_dragon.tscn")
const SHIP := preload("res://Scenes/Ship/ship.tscn")
const ENERGY_PATH := "res://Scenes/Modules/Energy/energy_module.tscn"
const FLAME_PATH := "res://Scenes/Modules/Weapons/Flamethrower/flamethrower.tscn"
const LASER_PATH := "res://Scenes/Modules/Weapons/Laser/laser.tscn"

var failures: Array[String] = []
var projectile_hits: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var recipe := WeaponFusionRegistry.find_recipe(&"flamethrower", &"laser")
	_check(recipe.get("result_id", &"") == &"flame_laser", "Flamethrower + Laser resolves to Flame Laser")
	_check(WeaponFusionRegistry.find_recipe(&"laser", &"flamethrower").get("result_id", &"") == &"flame_laser", "reverse recipe resolves")
	_check(ModuleCatalog.get_entry(&"flame_laser").get("fusion_only", false), "fusion result appears in module catalog")
	var research := ResearchManager.get_weapon_research_definition(&"flame_laser")
	_check(research != null and research.max_level == 30 and research.category_id == &"fusion_weapon", "independent Level 1-30 research exists")
	var research_key := "weapon_damage.flame_laser"
	var saved_research_level := int(ResearchManager.progress.levels.get(research_key, 1))
	ResearchManager.progress.levels[research_key] = 1

	var weapon := WEAPON.instantiate() as FusionWeapon
	add_child(weapon)
	weapon.set_process(false)
	_check(weapon.attack_kind == FusionWeapon.AttackKind.BEAM, "fusion is a beam weapon")
	_check(is_equal_approx(weapon.attack_range, 600.0), "targeting range is 600 px")
	_check(is_equal_approx(weapon.basic_damage, 1.0), "base damage is one")
	_check(is_equal_approx(weapon.attack_interval, 0.1), "base tick interval is 0.1 s")
	_check(is_equal_approx(weapon.rotation_speed, 120.0), "Flame Laser rotates at 120 degrees per second")
	_check(is_equal_approx(float(weapon.get("doubling_interval")), 1.0), "doubling interval is 1.0 s")
	_check(is_equal_approx(float(weapon.get("maximum_tick_damage")), 256.0), "damage cap is 256 per tick")
	_check(weapon.get_power_consumption() == 4, "combined power cost is four")
	ResearchManager.progress.levels[research_key] = 2
	_check(is_equal_approx(weapon.get_damage(), 1.2), "fusion research scales base tick damage")
	ResearchManager.progress.levels[research_key] = 30
	_check(is_equal_approx(weapon.get_damage(), 6.8), "Level 30 starts at 6.8 damage per tick")
	ResearchManager.progress.levels[research_key] = 1
	weapon.projectile_hit.connect(func(_enemy: BasicEnemy, _amount: float) -> void: projectile_hits += 1)

	var target := _enemy(Vector2(300.0, 0.0))
	var bystander := _enemy(Vector2(150.0, 0.0))
	var turret := weapon.get_node("Turret") as Node2D
	weapon.current_target = target
	target.position = Vector2(650.0, 0.0)
	turret.rotation = PI
	weapon._process(0.1)
	_check(weapon.current_target == target, "turning behind an out-of-range target does not lose lock")
	_check(is_equal_approx(target.get_current_health(), target.max_health), "locked target outside range takes no damage")
	_check(is_equal_approx(bystander.get_current_health(), bystander.max_health), "closer enemy does not steal the lock")
	target.position = Vector2(300.0, 0.0)
	turret.rotation = 0.0
	weapon._process(0.0)
	_check(is_equal_approx(target.max_health - target.get_current_health(), 1.0), "first lock deals one damage")
	_check(is_equal_approx(bystander.get_current_health(), bystander.max_health), "beam does not pierce another enemy")
	for index in range(9):
		weapon.fire()
	_check(is_equal_approx(target.max_health - target.get_current_health(), 10.0), "first ten ticks deal base damage")
	weapon.fire()
	_check(is_equal_approx(target.max_health - target.get_current_health(), 12.0), "eleventh tick doubles to two")
	for index in range(69):
		weapon.fire()
	var before_cap := target.get_current_health()
	weapon.fire()
	_check(is_equal_approx(before_cap - target.get_current_health(), 256.0), "ramp caps individual tick at 256")
	_check(projectile_hits == 0, "continuous beam emits no projectile hit event")

	turret.rotation = PI
	weapon.current_target = bystander
	weapon._process(0.0)
	_check(int(weapon.get("_doublings")) == 0, "switching target resets ramp before turret finishes turning")
	turret.rotation = 0.0
	weapon._process(0.0)
	_check(is_equal_approx(bystander.max_health - bystander.get_current_health(), 1.0), "switching target resets charge to one")
	weapon.add_artifact_fire_rate_bonus(Callable(self, "_double_fire_rate"))
	_check(is_equal_approx(weapon.get_fire_rate(), 20.0), "attack speed doubles tick frequency")
	var previous_health := bystander.get_current_health()
	for index in range(10):
		weapon._process(0.05)
	_check(is_equal_approx(previous_health - bystander.get_current_health(), 11.0), "ten boosted ticks reach doubled damage in 0.5 s")
	weapon.remove_artifact_fire_rate_bonus(Callable(self, "_double_fire_rate"))

	var boss := ANCIENT_DRAGON.instantiate() as AncientDragon
	add_child(boss)
	boss.set_physics_process(false)
	boss.global_position = Vector2(300.0, 0.0)
	weapon.current_target = boss
	turret.rotation = 0.0
	weapon._process(0.0)
	weapon._doublings = 5
	boss.take_damage(AncientDragon.SEGMENT_HP - 2.0)
	weapon.fire()
	_check(boss.segments_broken == 1, "Flame Laser can break one Ancient Dragon health segment")
	boss._begin_dive_qte()
	boss.force_resolve_dive_for_testing(true)
	var next_segment_before := boss.get_current_health()
	weapon.fire()
	_check(is_equal_approx(next_segment_before - boss.get_current_health(), 1.0), "a new boss health segment resets Flame Laser to base damage")
	_check(weapon._doublings == 0, "boss segment switch clears Flame Laser ramp stacks")
	ResearchManager.progress.levels[research_key] = saved_research_level

	weapon.queue_free()
	boss.queue_free()
	target.queue_free()
	bystander.queue_free()
	var temp_dir := OS.get_environment("TMPDIR")
	var temporary_save := temp_dir.path_join("greedminer_flame_laser_fusion_%d.json" % Time.get_ticks_usec()) if not temp_dir.is_empty() else "user://greedminer_flame_laser_fusion_test.json"
	ProgressionStore.set_save_path_for_testing(temporary_save)
	ShipLoadout.installed_modules.clear()
	ShipLoadout.install_module(1, 1, ENERGY_PATH)
	ShipLoadout.install_module(0, 0, FLAME_PATH)
	ShipLoadout.install_module(0, 1, LASER_PATH)
	var ship := SHIP.instantiate() as Ship
	add_child(ship)
	await get_tree().process_frame
	_check(ship.fuse_modules(Vector2i(0, 0), Vector2i(0, 1), WEAPON), "ship fuses installed Flame and Laser modules")
	_check(ship.get_module_at(0, 1) is FusionWeapon and ship.get_module_at(0, 0) == null, "fusion leaves one Flame Laser on the ship")
	_check(ShipLoadout.get_module(0, 1) == WEAPON.resource_path, "fusion result path is saved in the loadout")
	ship.queue_free()
	if failures.is_empty():
		print("FLAME_LASER_TEST: PASS")
	else:
		for failure in failures:
			push_error("FLAME_LASER_TEST: " + failure)
	get_tree().quit(1 if not failures.is_empty() else 0)


func _double_fire_rate() -> float:
	return 1.0


func _enemy(at: Vector2) -> BasicEnemy:
	var enemy := ENEMY.instantiate() as BasicEnemy
	enemy.max_health = 100000.0
	add_child(enemy)
	enemy.set_physics_process(false)
	enemy.position = at
	return enemy


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
