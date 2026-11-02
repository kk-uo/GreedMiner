extends Node2D

const SAVE := preload("res://Tests/TestSave.gd")
const GUN := preload("res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn")
const ENEMY := preload("res://Scenes/Enemies/little_rock.tscn")
const SHIP := preload("res://Scenes/Ship/ship.tscn")
const MEGA_MONSTER := preload("res://Scenes/Enemies/mega_monster.tscn")

var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SAVE.isolate("zombie_arm_blizzard")
	ArtifactManager.reload_progress()
	var arm_definition := ArtifactManager.get_definition(&"zombie_arm")
	var bottle_definition := ArtifactManager.get_definition(&"blizzard_bottle")
	_check(arm_definition != null and arm_definition.rarity == "Rare", "Zombie Arm registered as Rare")
	_check(arm_definition != null and arm_definition.is_compatible_with_module(&"machine_gun") and not arm_definition.is_compatible_with_module(&"laser"), "Zombie Arm requires a bullet turret")
	_check(arm_definition in ArtifactManager.get_unowned_mining_chest_artifacts(&"graveyard_planet"), "Zombie Arm is a Graveyard chest reward")
	_check(arm_definition not in ArtifactManager.get_unowned_mining_chest_artifacts(&"frozen_planet"), "Zombie Arm does not drop on Frozen Planet")
	_check(bottle_definition != null and bottle_definition.equip_target == MagicArtifactDefinition.EquipTarget.SHIP, "Blizzard Bottle uses a ship slot")
	_check(bottle_definition not in ArtifactManager.get_unowned_mining_chest_artifacts(&"frozen_planet"), "Blizzard Bottle is not a chest reward")
	var boss := MEGA_MONSTER.instantiate() as FrozenEnemy
	boss._perform_death_effect()
	_check(ArtifactManager.owns_artifact(&"blizzard_bottle") and not ArtifactManager.owns_artifact(&"frost_breath"), "Frozen boss grants Bottle without granting Frost Breath")
	var count_after_boss := ArtifactManager.acquired_order.size()
	boss._perform_death_effect()
	_check(ArtifactManager.acquired_order.size() == count_after_boss, "Frozen boss reward does not duplicate")
	boss.free()
	_check(ArtifactManager.grant_artifact(&"zombie_arm"), "Zombie Arm grants once")
	_check(not ArtifactManager.grant_artifact(&"zombie_arm"), "Zombie Arm cannot duplicate")
	_check(arm_definition not in ArtifactManager.get_unowned_mining_chest_artifacts(&"graveyard_planet"), "owned Zombie Arm leaves chest pool")
	ArtifactManager.reload_progress()
	_check(ArtifactManager.owns_artifact(&"zombie_arm"), "Zombie Arm persists after reload")

	var gun := GUN.instantiate() as MachineGun
	add_child(gun)
	gun.set_process(false)
	var arm_effect := arm_definition.effect_script.new() as MagicArtifactEffect
	arm_effect.configure(arm_definition, null)
	arm_effect.call("configure_weapon", gun)
	add_child(arm_effect)
	gun.fire()
	gun.fire()
	_check(_arms().is_empty(), "first two attacks launch no Zombie Arm")
	gun.fire()
	_check(_arms().size() == 1, "third attack launches one Zombie Arm")
	if not _arms().is_empty():
		var projectile := _arms()[0]
		_check(is_equal_approx(projectile.damage, 50.0), "Zombie Arm uses fixed 50 damage")
		var victim := ENEMY.instantiate() as BasicEnemy
		victim.max_health = 200.0
		victim.move_speed = 0.0
		add_child(victim)
		projectile._on_area_entered(victim)
		_check(is_equal_approx(victim.get_current_health(), 150.0), "Zombie Arm deals 50 damage through normal hit pipeline")
		victim.queue_free()
	arm_effect.cleanup()
	gun.fire()
	_check(_arms().is_empty(), "unequipping stops new Zombie Arms")
	for projectile in _arms():
		projectile.queue_free()
	gun.queue_free()
	await get_tree().process_frame
	var fusion := ModuleCatalog.get_scene(&"scatter_machine_gun").instantiate() as FusionWeapon
	add_child(fusion)
	fusion.set_process(false)
	var fusion_effect := arm_definition.effect_script.new() as MagicArtifactEffect
	fusion_effect.configure(arm_definition, null)
	fusion_effect.call("configure_weapon", fusion)
	add_child(fusion_effect)
	fusion.fire()
	fusion.fire()
	_check(_arms().is_empty(), "fusion volleys also wait for the third attack")
	fusion.fire()
	_check(_arms().size() == 1, "fusion projectile weapon launches one arm per third volley")
	fusion_effect.cleanup()
	for projectile in _arms():
		projectile.queue_free()
	fusion.queue_free()
	await get_tree().process_frame

	ShipLoadout.installed_modules.clear()
	var ship := SHIP.instantiate() as Ship
	add_child(ship)
	var center := ship.to_global(Ship.SHIP_SIZE * 0.5)
	var close_enemy := _enemy_at(center + Vector2(50, 0), BasicEnemy.EnemyTier.COMMON)
	var close_boss := _enemy_at(center + Vector2(160, 0), BasicEnemy.EnemyTier.BOSS)
	var far_enemy := _enemy_at(center + Vector2(250, 0), BasicEnemy.EnemyTier.COMMON)
	var bottle_effect := bottle_definition.effect_script.new() as MagicArtifactEffect
	bottle_effect.configure(bottle_definition, ship)
	add_child(bottle_effect)
	await get_tree().physics_frame
	_check(is_equal_approx(close_enemy.get_effective_move_speed(), close_enemy.move_speed * 0.7), "near enemy slowed 30 percent")
	_check(is_equal_approx(close_boss.get_effective_move_speed(), close_boss.move_speed * 0.7), "near boss slowed 30 percent")
	_check(is_equal_approx(far_enemy.get_effective_move_speed(), far_enemy.move_speed), "outside enemy not slowed")
	close_enemy.global_position = center + Vector2(230, 0)
	for index in range(8):
		await get_tree().physics_frame
	_check(is_equal_approx(close_enemy.get_effective_move_speed(), close_enemy.move_speed), "leaving aura removes slow")
	bottle_effect.cleanup()
	_check(is_equal_approx(close_boss.get_effective_move_speed(), close_boss.move_speed), "battle cleanup removes aura slow")
	close_enemy.queue_free()
	close_boss.queue_free()
	far_enemy.queue_free()
	ship.queue_free()
	ShipLoadout.installed_modules.clear()
	if failures.is_empty():
		print("ZOMBIE_ARM_BLIZZARD_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("ZOMBIE_ARM_BLIZZARD_TEST: " + failure)
		get_tree().quit(1)


func _arms() -> Array[ZombieArmProjectile]:
	var result: Array[ZombieArmProjectile] = []
	for child in get_children():
		if child is ZombieArmProjectile and not child.is_queued_for_deletion():
			result.append(child)
	return result


func _enemy_at(at: Vector2, tier: BasicEnemy.EnemyTier) -> BasicEnemy:
	var enemy := ENEMY.instantiate() as BasicEnemy
	enemy.max_health = 200.0
	enemy.move_speed = 20.0
	enemy.enemy_tier = tier
	add_child(enemy)
	enemy.global_position = at
	enemy.set_physics_process(false)
	return enemy


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
