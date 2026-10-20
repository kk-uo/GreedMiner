extends Node

## Headless integration coverage for knockback pre-attack interception and
## additive regeneration. The test uses only the in-memory loadout.

const SHIP_SCENE := preload("res://Scenes/Ship/ship.tscn")
const ENERGY_SCENE := preload("res://Scenes/Modules/Energy/energy_module.tscn")
const KNOCKBACK_SCENE := preload("res://Scenes/Modules/Shield/knockback_module.tscn")
const REGENERATION_SCENE := preload("res://Scenes/Modules/Shield/regeneration_module.tscn")
const GOBLIN_SCENE := preload("res://Scenes/Enemies/goblin.tscn")
const ELITE_SCENE := preload("res://Scenes/Enemies/elite_goblin.tscn")
const BOSS_SCENE := preload("res://Scenes/Enemies/rock_titan.tscn")
const TEST_SAVE_PATH := "user://shield_module_system_test.json"

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_remove_test_save()
	ProgressionStore.set_save_path_for_testing(TEST_SAVE_PATH)
	WeaponUnlockManager.reload_progress()
	_expect_true(not WeaponUnlockManager.is_weapon_unlocked(&"knockback_module"), "Knockback starts locked until the Goblin boss falls")
	WeaponUnlockManager.record_planet_completion(&"goblin_planet")
	# Regeneration is planned for a later update; unlock it for coverage.
	WeaponUnlockManager.unlock_all_configured_weapons()
	ShipLoadout.installed_modules.clear()
	var ship := SHIP_SCENE.instantiate() as Ship
	add_child(ship)
	await get_tree().process_frame
	ship.global_position = Vector2(500.0, 350.0)

	_expect_true(ship.install_module(KNOCKBACK_SCENE, Ship.ModuleType.Shield, 0, 0), "Knockback installs")
	_expect_equal(ship.max_hp, 100.0, "Knockback grants exactly 50 max HP")
	var module := ship.get_module_at(0, 0) as KnockbackModule
	_expect_equal(module.trigger_range, 64.0, "trigger range defaults to 64")
	_expect_equal(module.splash_radius, 64.0, "splash radius defaults to 64")
	_expect_equal(module.knockback_damage, 25.0, "damage defaults to 25")
	_expect_equal(module.knockback_distance, 100.0, "distance defaults to 100")
	_expect_equal(module.cooldown, 2.0, "cooldown defaults to 2 seconds")

	var trigger := await _spawn_enemy(GOBLIN_SCENE, ship, Vector2(Ship.SHIP_SIZE.x + 5.0, 96.0), 100.0)
	var splash := await _spawn_enemy(GOBLIN_SCENE, ship, Vector2(Ship.SHIP_SIZE.x + 45.0, 96.0), 100.0)
	var outside := await _spawn_enemy(GOBLIN_SCENE, ship, Vector2(Ship.SHIP_SIZE.x + 140.0, 96.0))
	var trigger_before := trigger.global_position
	var ship_hp_before := ship.current_hp
	await get_tree().create_timer(1.1).timeout
	_expect_equal(ship.current_hp, ship_hp_before, "valid activation interrupts pending attack")
	_expect_equal(trigger.get_current_health(), 75.0, "trigger receives exactly 25 damage")
	_expect_equal(splash.get_current_health(), 75.0, "nearby overlapping common receives exactly 25 splash damage")
	_expect_equal(outside.get_current_health(), 20.0, "enemy outside splash is unaffected")
	_expect_true(trigger.global_position.distance_to(trigger_before) >= 90.0, "trigger is displaced outward before it resumes movement")
	trigger.queue_free()
	splash.queue_free()
	outside.queue_free()
	await get_tree().process_frame

	# Direct pre-attack invocation verifies the instantaneous configured distance
	# before normal enemy movement begins on the following physics frame.
	module._cooldown_remaining = 0.0
	var distance_probe := await _spawn_enemy(GOBLIN_SCENE, ship, Vector2(Ship.SHIP_SIZE.x + 5.0, 170.0), 100.0)
	var probe_before := distance_probe.global_position
	_expect_true(module.try_interrupt_attack(distance_probe, ship), "eligible pending attack activates directly")
	_expect_near(distance_probe.global_position.distance_to(probe_before), 100.0, 0.01, "instant knockback distance is exactly 100")
	distance_probe.queue_free()
	await get_tree().process_frame

	# Cooldown means the next valid attack is not interrupted.
	var cooldown_enemy := await _spawn_enemy(GOBLIN_SCENE, ship, Vector2(Ship.SHIP_SIZE.x + 5.0, 40.0))
	await get_tree().create_timer(1.1).timeout
	_expect_equal(ship.current_hp, ship_hp_before - 5.0, "attack during cooldown proceeds normally")
	cooldown_enemy.queue_free()
	await get_tree().process_frame

	# Being close is insufficient until an actual timer attack occurs.
	module._cooldown_remaining = 0.0
	var idle_enemy := await _spawn_enemy(GOBLIN_SCENE, ship, Vector2(Ship.SHIP_SIZE.x + 20.0, 150.0))
	idle_enemy._stop_attacking()
	var idle_hp := idle_enemy.get_current_health()
	await get_tree().create_timer(0.2).timeout
	_expect_equal(idle_enemy.get_current_health(), idle_hp, "nearby non-attacking enemy does not trigger")
	idle_enemy.queue_free()

	# Large/elite can trigger; finalized knockback damage is exact effect damage.
	var elite := await _spawn_enemy(ELITE_SCENE, ship, Vector2(Ship.SHIP_SIZE.x + 5.0, 96.0))
	var elite_before := elite.global_position
	await get_tree().create_timer(1.1).timeout
	_expect_equal(elite.get_current_health(), 175.0, "elite receives exactly 25 knockback damage")
	_expect_equal(ship.current_hp, ship_hp_before - 5.0, "elite pending attack is interrupted")
	_expect_true(elite.global_position.distance_to(elite_before) >= 90.0, "surviving elite is knocked outward")
	elite.queue_free()

	# Bosses bypass both trigger and splash eligibility.
	module._cooldown_remaining = 0.0
	var boss := await _spawn_enemy(BOSS_SCENE, ship, Vector2(Ship.SHIP_SIZE.x + 5.0, 96.0))
	var boss_hp := boss.get_current_health()
	await get_tree().create_timer(1.1).timeout
	_expect_equal(boss.get_current_health(), boss_hp, "boss is excluded from knockback damage")
	_expect_true(ship.current_hp < ship_hp_before - 5.0, "boss attack is not interrupted")
	boss.queue_free()

	# A far pending attack cannot activate even when its own attack range allows it.
	module._cooldown_remaining = 0.0
	var far := await _spawn_enemy(GOBLIN_SCENE, ship, Vector2(Ship.SHIP_SIZE.x + 90.0, 96.0))
	far.attack_range = 100.0
	var far_ship_hp := ship.current_hp
	await get_tree().create_timer(1.1).timeout
	_expect_equal(ship.current_hp, far_ship_hp - 5.0, "pending attack outside 64 does not trigger")
	far.queue_free()

	# Runtime max-HP changes do not heal. Regeneration stacks additively and caps.
	ship.current_hp = ship.max_hp
	ship.take_damage(40.0)
	var damaged_hp := ship.current_hp
	_expect_true(ship.install_module(REGENERATION_SCENE, Ship.ModuleType.Shield, 0, 1), "Regeneration installs")
	_expect_equal(ship.max_hp, 150.0, "Regeneration adds 50 max HP")
	_expect_equal(ship.current_hp, damaged_hp, "max HP increase does not auto-heal")
	await get_tree().create_timer(1.1).timeout
	_expect_equal(ship.current_hp, damaged_hp + 1.0, "one Regeneration restores 1 HP per second")
	_expect_true(ship.install_module(REGENERATION_SCENE, Ship.ModuleType.Shield, 0, 2), "second Regeneration installs")
	var before_two := ship.current_hp
	await get_tree().create_timer(1.1).timeout
	_expect_equal(ship.current_hp, before_two + 2.0, "two Regeneration modules stack additively")

	# Persistence stores both scene paths through the existing loadout section.
	_expect_true(ShipLoadout.get_module(0, 0).ends_with("knockback_module.tscn"), "Knockback path is in loadout")
	_expect_true(ShipLoadout.get_module(0, 1).ends_with("regeneration_module.tscn"), "Regeneration path is in loadout")
	_expect_true(ShipLoadout.save(), "shield loadout saves through ProgressionStore")
	ShipLoadout.installed_modules.clear()
	ProgressionStore.reload_from_disk()
	ShipLoadout.load_saved()
	_expect_true(ShipLoadout.get_module(0, 0).ends_with("knockback_module.tscn"), "Knockback restores from disk")
	_expect_true(ShipLoadout.get_module(0, 1).ends_with("regeneration_module.tscn"), "Regeneration restores from disk")

	ship.queue_free()
	ShipLoadout.installed_modules.clear()
	_remove_test_save()
	await get_tree().process_frame
	_finish()


func _remove_test_save() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEST_SAVE_PATH)
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(absolute_path)


func _spawn_enemy(scene: PackedScene, ship: Ship, local_position: Vector2, health_override: float = -1.0) -> BasicEnemy:
	var enemy := scene.instantiate() as BasicEnemy
	if health_override > 0.0:
		enemy.max_health = health_override
	enemy.target_ship = ship
	add_child(enemy)
	enemy.global_position = ship.to_global(local_position)
	await get_tree().physics_frame
	return enemy


func _finish() -> void:
	if _failures.is_empty():
		print("SHIELD_MODULE_SYSTEM_TEST: PASS")
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error("SHIELD_MODULE_SYSTEM_TEST: " + failure)
	print("SHIELD_MODULE_SYSTEM_TEST: FAIL (%d failures)" % _failures.size())
	get_tree().quit(1)


func _expect_true(value: bool, description: String) -> void:
	if not value:
		_failures.append(description)


func _expect_equal(actual: Variant, expected: Variant, description: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [description, expected, actual])


func _expect_near(actual: float, expected: float, tolerance: float, description: String) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %s ± %s, got %s)" % [description, expected, tolerance, actual])
