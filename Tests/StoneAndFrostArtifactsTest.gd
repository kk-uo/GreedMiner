extends Node

## Isolated progression and live effect regression coverage for the new items.
const GUN := preload("res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn")
const ENEMY := preload("res://Scenes/Enemies/little_rock.tscn")
const MEGA_MONSTER := preload("res://Scenes/Enemies/mega_monster.tscn")

var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	ProgressionStore.set_save_path_for_testing("/private/tmp/greedminer_stone_frost_%d.json" % Time.get_ticks_usec())
	_check(ProgressionStore.reset_all_progress(), "isolated temporary save is writable")
	ArtifactManager.reload_progress()
	var red := ArtifactManager.get_definition(&"red_stone")
	var black := ArtifactManager.get_definition(&"black_stone")
	var frost := ArtifactManager.get_definition(&"frost_breath")
	_check(red != null and red.rarity == "Common", "Red Stone registered as Common")
	_check(black != null and black.rarity == "Common", "Black Stone registered as Common")
	_check(frost != null and frost.rarity == "Legendary", "Frost Breath registered as Legendary")
	_check(red.equip_target == MagicArtifactDefinition.EquipTarget.MODULE and black.equip_target == MagicArtifactDefinition.EquipTarget.MODULE and frost.equip_target == MagicArtifactDefinition.EquipTarget.MODULE, "all three equip only on modules")
	_check(frost.is_compatible_with_module(&"machine_gun") and not frost.is_compatible_with_module(&"chainsaw"), "Frost Breath requires a target-locking turret")
	_check(ArtifactManager.configuration.get_validation_errors().is_empty(), "artifact registry validates")
	_check(red in ArtifactManager.get_unowned_mining_chest_artifacts(&"rocky_planet"), "Red Stone in Rocky chest pool")
	_check(black in ArtifactManager.get_unowned_mining_chest_artifacts(&"rocky_planet"), "Black Stone in Rocky chest pool")
	_check(frost not in ArtifactManager.get_unowned_mining_chest_artifacts(&"frozen_planet"), "Frost Breath is not a chest reward")
	_check(red not in ArtifactManager.get_unowned_mining_chest_artifacts(&"frozen_planet"), "Rocky stones do not drop on Frozen Planet")
	_check(ArtifactManager.grant_artifact(&"red_stone"), "Red Stone grants once")
	_check(not ArtifactManager.grant_artifact(&"red_stone"), "Red Stone cannot duplicate")
	_check(red not in ArtifactManager.get_unowned_mining_chest_artifacts(&"rocky_planet"), "owned Red Stone leaves chest pool")
	_check(ArtifactManager.grant_artifact(&"black_stone"), "Black Stone grants once")
	_check(not ArtifactManager.grant_artifact(&"black_stone"), "Black Stone cannot duplicate")
	var mega_monster := MEGA_MONSTER.instantiate() as FrozenEnemy
	add_child(mega_monster)
	mega_monster._perform_death_effect()
	_check(ArtifactManager.owns_artifact(&"frost_breath"), "Mega Monster defeat hook grants Frost Breath")
	var acquired_count := ArtifactManager.acquired_order.size()
	mega_monster._perform_death_effect()
	_check(ArtifactManager.acquired_order.size() == acquired_count, "repeated boss hook does not duplicate Frost Breath")
	mega_monster.queue_free()
	_check(not ArtifactManager.grant_artifact(&"frost_breath"), "Frost Breath cannot duplicate")
	ArtifactManager.reload_progress()
	_check(ArtifactManager.owns_artifact(&"red_stone") and ArtifactManager.owns_artifact(&"black_stone") and ArtifactManager.owns_artifact(&"frost_breath"), "ownership persists after reload")

	var gun := GUN.instantiate() as MachineGun
	add_child(gun)
	gun.set_process(false)
	var research_key := "weapon_damage.machine_gun"
	var previous_level := int(ResearchManager.progress.levels.get(research_key, 1))
	ResearchManager.progress.levels[research_key] = 1
	var base := gun.basic_damage
	var red_effect := _attach_effect(red, gun)
	_check(is_equal_approx(gun.get_damage(), base * 1.1), "Red Stone adds 10 percent final damage")
	red_effect.cleanup()
	_check(is_equal_approx(gun.get_damage(), base), "Red Stone cleans up")
	var black_effect := _attach_effect(black, gun)
	_check(is_equal_approx(gun.get_damage(), base + 1.0), "Black Stone adds one base damage at level one")
	ResearchManager.progress.levels[research_key] = 10
	_check(is_equal_approx(gun.get_damage(), (base + 1.0) * 2.8), "Laboratory scales Black Stone base bonus")
	black_effect.cleanup()
	_check(is_equal_approx(gun.get_damage(), base * 2.8), "Black Stone cleans up")
	ResearchManager.progress.levels[research_key] = previous_level

	var regular := _enemy(BasicEnemy.EnemyTier.COMMON)
	var elite := _enemy(BasicEnemy.EnemyTier.LARGE)
	var boss := _enemy(BasicEnemy.EnemyTier.BOSS)
	regular.position = Vector2(100.0, 0.0)
	elite.position = Vector2(200.0, 0.0)
	boss.position = Vector2(300.0, 0.0)
	var frost_effect := _attach_effect(frost, gun)
	gun.current_target = regular
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(regular.is_artifact_frozen() and regular.process_mode == Node.PROCESS_MODE_DISABLED, "locked regular enemy cannot act")
	await get_tree().process_frame
	_check(_in_physics_world(regular), "frozen enemy remains projectile-collidable")
	var frozen_health := regular.get_current_health()
	regular.take_damage(3.0)
	_check(regular.get_current_health() < frozen_health, "frozen enemy still receives damage")
	gun.current_target = elite
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(not regular.is_artifact_frozen() and regular.process_mode == Node.PROCESS_MODE_INHERIT, "old target thaws after switching")
	_check(elite.is_artifact_frozen(), "elite target freezes")
	gun.current_target = boss
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(not elite.is_artifact_frozen(), "elite thaws when lock switches")
	_check(not boss.is_artifact_frozen(), "boss is immune")
	gun.current_target = regular
	await get_tree().physics_frame
	frost_effect.cleanup()
	_check(not regular.is_artifact_frozen(), "battle cleanup thaws target")
	gun.queue_free()
	regular.queue_free()
	elite.queue_free()
	boss.queue_free()
	if failures.is_empty():
		print("STONE_AND_FROST_ARTIFACTS_TEST: PASS")
	else:
		for failure in failures:
			push_error("STONE_AND_FROST_ARTIFACTS_TEST: " + failure)
	get_tree().quit(1 if not failures.is_empty() else 0)


func _attach_effect(definition: MagicArtifactDefinition, gun: MachineGun) -> MagicArtifactEffect:
	var effect := definition.effect_script.new() as MagicArtifactEffect
	effect.configure(definition, null)
	effect.call("configure_weapon", gun)
	add_child(effect)
	return effect


func _enemy(tier: BasicEnemy.EnemyTier) -> BasicEnemy:
	var enemy := ENEMY.instantiate() as BasicEnemy
	enemy.enemy_tier = tier
	add_child(enemy)
	return enemy


func _in_physics_world(enemy: BasicEnemy) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = enemy.global_position
	query.collision_mask = enemy.collision_layer
	query.collide_with_areas = true
	for hit in enemy.get_world_2d().direct_space_state.intersect_point(query):
		if hit.get("collider") == enemy:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
