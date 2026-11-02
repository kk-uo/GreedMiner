extends Node

const MACHINE_GUN := preload("res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn")
const BULLET := preload("res://Scenes/Modules/Weapons/MachineGun/machine_gun_projectile.tscn")
const CANNON := preload("res://Scenes/Modules/Weapons/DwarfCannon/dwarf_cannon.tscn")
const FLAMETHROWER := preload("res://Scenes/Modules/Weapons/Flamethrower/flamethrower.tscn")
const LASER := preload("res://Scenes/Modules/Weapons/Laser/laser.tscn")
const ENEMY := preload("res://Scenes/Enemies/little_rock.tscn")

var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	ProgressionStore.set_save_path_for_testing("/private/tmp/greedminer_new_artifacts_%d.json" % Time.get_ticks_usec())
	_check(ProgressionStore.reset_all_progress(), "temporary artifact save is writable")
	ArtifactManager.reload_progress()
	var tooth := ArtifactManager.get_definition(&"goblin_tooth")
	var eye := ArtifactManager.get_definition(&"bat_eyeball")
	var wing := ArtifactManager.get_definition(&"dragon_wing")
	_check(tooth != null and tooth.rarity == "Rare", "Goblin Tooth is registered as Rare")
	_check(eye != null and eye.rarity == "Epic", "Bat Eyeball is registered as Epic")
	_check(wing != null and wing.rarity == "Rare", "Dragon Wing is registered as Rare")
	_check(ArtifactManager.configuration.get_validation_errors().is_empty(), "artifact registry validates")
	_check(tooth in ArtifactManager.get_unowned_mining_chest_artifacts(&"goblin_planet"), "Goblin Tooth drops from Verdant mining chests")
	_check(eye in ArtifactManager.get_unowned_mining_chest_artifacts(&"graveyard_planet"), "Bat Eyeball drops from Graveyard mining chests")
	_check(wing in ArtifactManager.get_unowned_mining_chest_artifacts(&"dragon_nest_planet"), "Dragon Wing drops from Dragon Nest mining chests")
	_check(tooth not in ArtifactManager.get_unowned_mining_chest_artifacts(&"graveyard_planet"), "new chest rewards stay planet-specific")

	var gun := MACHINE_GUN.instantiate() as MachineGun
	add_child(gun)
	gun.set_process(false)
	var research_key := "weapon_damage.machine_gun"
	var old_level := int(ResearchManager.progress.levels.get(research_key, 1))
	ResearchManager.progress.levels[research_key] = 1
	var base_damage := gun.basic_damage
	var tooth_effect := _attach(tooth, gun)
	_check(is_equal_approx(gun.get_damage(), base_damage * 1.15), "Goblin Tooth adds 15 percent final turret damage")
	tooth_effect.cleanup()
	_check(is_equal_approx(gun.get_damage(), base_damage), "Goblin Tooth cleanup removes its damage bonus")

	var cannon := CANNON.instantiate() as DwarfCannon
	add_child(cannon)
	cannon.set_process(false)
	var flying_probe := BasicEnemy.new()
	flying_probe.movement_type = BasicEnemy.MovementType.FLYING
	_check(not cannon.can_target_enemy(flying_probe), "ground-only cannon initially rejects flying enemies")
	var wing_effect := _attach(wing, cannon)
	_check(cannon.can_target_enemy(flying_probe), "Dragon Wing enables cannon anti-air targeting")
	wing_effect.cleanup()
	_check(not cannon.can_target_enemy(flying_probe), "Dragon Wing cleanup restores ground-only targeting")
	flying_probe.free()

	var eye_effect := _attach(eye, gun)
	_check(is_equal_approx(gun.get_artifact_projectile_homing_turn_rate(), 30.0), "Bat Eyeball gives projectiles gentle homing")
	_check(is_equal_approx(gun.get_artifact_homing_range(), 600.0), "Bat Eyeball homing range is data-driven")
	var homing_target := _enemy(Vector2(160.0, 100.0))
	var bullet := BULLET.instantiate() as MachineGunProjectile
	bullet.source_weapon = gun
	bullet.direction = Vector2.RIGHT
	bullet.speed = 100.0
	add_child(bullet)
	bullet.set_process(false)
	bullet._process(1.0)
	_check(bullet.direction.y > 0.1 and bullet.direction.angle() <= deg_to_rad(30.1), "Bat Eyeball bends a projectile toward its target by the configured limit")
	bullet.enable_ghost_piercing(1)
	_check(bullet._ghost != null and gun.get_artifact_projectile_homing_turn_rate() > 0.0, "Bat Eyeball and Ghost Bullet remain active together")

	var flame := FLAMETHROWER.instantiate() as Flamethrower
	add_child(flame)
	flame.set_process(false)
	var flame_eye_effect := _attach(eye, flame)
	_check(is_equal_approx(flame.get_artifact_flame_homing_turn_rate(), 120.0), "Bat Eyeball gives flame stronger target following")

	var laser := LASER.instantiate() as Laser
	add_child(laser)
	laser.set_physics_process(false)
	var laser_eye_effect := _attach(eye, laser)
	var first := _enemy(Vector2(100.0, 0.0))
	var second := _enemy(Vector2(260.0, 20.0))
	var path := laser.get_artifact_laser_path(Vector2.ZERO, Vector2.RIGHT, 500.0, first)
	_check(path.size() == 3 and path[2].y > 0.0, "Bat Eyeball bends a laser slightly after its first target")

	laser_eye_effect.cleanup()
	flame_eye_effect.cleanup()
	eye_effect.cleanup()
	ResearchManager.progress.levels[research_key] = old_level
	gun.queue_free()
	cannon.queue_free()
	flame.queue_free()
	laser.queue_free()
	homing_target.queue_free()
	first.queue_free()
	second.queue_free()
	if is_instance_valid(bullet):
		bullet.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("NEW_MAGIC_ARTIFACTS_TEST: PASS")
	else:
		for failure in failures:
			push_error("NEW_MAGIC_ARTIFACTS_TEST: " + failure)
	get_tree().quit(1 if not failures.is_empty() else 0)


func _attach(definition: MagicArtifactDefinition, weapon: WeaponModule) -> MagicArtifactEffect:
	var effect := definition.effect_script.new() as MagicArtifactEffect
	effect.configure(definition, null)
	effect.call("configure_weapon", weapon)
	add_child(effect)
	return effect


func _enemy(at: Vector2) -> BasicEnemy:
	var enemy := ENEMY.instantiate() as BasicEnemy
	enemy.max_health = 1000.0
	enemy.move_speed = 0.0
	add_child(enemy)
	enemy.global_position = at
	enemy.set_physics_process(false)
	return enemy


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
