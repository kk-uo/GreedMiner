extends Node

const MACHINE_GUN := preload("res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn")
const DWARF_CANNON := preload("res://Scenes/Modules/Weapons/DwarfCannon/dwarf_cannon.tscn")
const SCATTER_GUN := preload("res://Scenes/Modules/Weapons/Fusion/scatter_machine_gun.tscn")
const SIEGE_CANNON := preload("res://Scenes/Modules/Weapons/Fusion/siege_cannon.tscn")
const GHOST_STATE := preload("res://Scripts/Modules/Weapons/GhostProjectileState.gd")

var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	ProgressionStore.set_save_path_for_testing("/private/tmp/greedminer_sturdy_twin_%d.json" % Time.get_ticks_usec())
	_check(ProgressionStore.reset_all_progress(), "temporary artifact save is writable")
	ArtifactManager.reload_progress()

	var sturdy := ArtifactManager.get_definition(&"sturdy_stone")
	var twin := ArtifactManager.get_definition(&"twin_demon")
	var ghost := ArtifactManager.get_definition(&"ghost_bullet")
	_check(sturdy != null and sturdy.rarity == "Rare", "Sturdy Stone is registered as Rare")
	_check(twin != null and twin.rarity == "Legendary", "Twin Demon is registered as Legendary")
	_check(ArtifactManager.configuration.get_validation_errors().is_empty(), "artifact registry validates")
	_check(sturdy in ArtifactManager.get_unowned_mining_chest_artifacts(&"rocky_planet"), "Sturdy Stone drops from Rocky mining chests")
	_check(twin in ArtifactManager.get_unowned_mining_chest_artifacts(&"volcanic_planet"), "Twin Demon drops from Volcanic mining chests")
	_check(sturdy not in ArtifactManager.get_unowned_mining_chest_artifacts(&"volcanic_planet"), "the new chest rewards stay planet-specific")

	var gun := MACHINE_GUN.instantiate() as MachineGun
	add_child(gun)
	gun.set_process(false)
	var sturdy_effect := _attach(sturdy, gun)
	_check(gun.get_artifact_projectile_pierces() == 1, "Sturdy Stone adds one penetration")
	_check(not gun.has_artifact_ghost_projectile(), "Sturdy Stone does not grant Ghost Bullet kill refunds")
	gun.fire()
	var sturdy_bullets := _machine_gun_projectiles()
	_check(sturdy_bullets.size() == 1, "Sturdy Stone does not change projectile count")
	if sturdy_bullets.size() == 1:
		var bullet := sturdy_bullets[0] as MachineGunProjectile
		_check(bullet._ghost != null and not bullet._ghost.replenish_on_kill, "Sturdy projectile uses fixed, non-refunding penetration")
		_check(not bullet._ghost_visual_enabled, "Sturdy projectile keeps its normal bullet appearance")
	_clear_projectiles()

	var ghost_effect := _attach(ghost, gun)
	_check(gun.get_artifact_projectile_pierces() == 2, "Sturdy Stone stacks with Ghost Bullet penetration")
	_check(gun.has_artifact_ghost_projectile(), "Ghost Bullet still enables kill refunds when stacked")
	var stacked_state := GHOST_STATE.new(gun.get_artifact_projectile_pierces(), gun.has_artifact_ghost_projectile())
	_check(stacked_state.continue_after_hit(true) and stacked_state.remaining == 2, "a Ghost kill refunds one penetration without losing Sturdy Stone's bonus")
	ghost_effect.cleanup()
	_check(gun.get_artifact_projectile_pierces() == 1 and not gun.has_artifact_ghost_projectile(), "Ghost cleanup preserves only Sturdy Stone's fixed pierce")
	sturdy_effect.cleanup()
	_check(gun.get_artifact_projectile_pierces() == 0, "Sturdy Stone cleanup removes its pierce")

	var twin_effect := _attach(twin, gun)
	_check(gun.get_artifact_projectile_count_bonus() == 1, "Twin Demon supplies one extra projectile")
	gun.fire()
	var twin_bullets := _machine_gun_projectiles()
	_check(twin_bullets.size() == 2, "Twin Demon makes a Machine Gun fire two projectiles")
	if twin_bullets.size() == 2:
		_check(twin_bullets[0].direction.is_equal_approx(twin_bullets[1].direction), "Twin Machine Gun shots stay parallel to the locked target")
		_check(not twin_bullets[0].global_position.is_equal_approx(twin_bullets[1].global_position), "Twin Machine Gun shots spawn as a visible pair")
		_check(twin_bullets[0].global_position.distance_to(twin_bullets[1].global_position) >= 14.0, "Twin Machine Gun shots fly side by side with a clear gap (Claude sync 97)")
	_clear_projectiles()
	twin_effect.cleanup()
	gun.fire()
	_check(_machine_gun_projectiles().size() == 1, "Twin Demon cleanup restores the normal volley")
	_clear_projectiles()

	var cannon := DWARF_CANNON.instantiate() as DwarfCannon
	add_child(cannon)
	cannon.set_process(false)
	var cannon_twin_effect := _attach(twin, cannon)
	cannon.fire()
	var twin_shells := _cannon_projectiles()
	_check(twin_shells.size() == 2, "Twin Demon makes a Dwarf Cannon fire two shells")
	if twin_shells.size() == 2:
		_check(twin_shells[0].direction.is_equal_approx(twin_shells[1].direction), "Twin cannon shells stay parallel to the locked target")
		_check(twin_shells[0].global_position.distance_to(twin_shells[1].global_position) >= 14.0, "Twin cannon shells fly side by side")
	_clear_projectiles()
	cannon_twin_effect.cleanup()

	var scatter := SCATTER_GUN.instantiate() as FusionWeapon
	add_child(scatter)
	scatter.set_process(false)
	var scatter_twin_effect := _attach(twin, scatter)
	scatter.fire()
	var scatter_shots := _fusion_projectiles()
	_check(scatter_shots.size() == 6, "Twin Demon adds one projectile to the Scatter Machine Gun's five-shot volley")
	if scatter_shots.size() == 6:
		_check(absf(rad_to_deg(scatter_shots[0].direction.angle()) + 18.0) < 0.01, "Twin Demon preserves the first original scatter trajectory")
		_check(absf(rad_to_deg(scatter_shots[4].direction.angle()) - 18.0) < 0.01, "Twin Demon preserves the last original scatter trajectory")
		_check(absf(scatter_shots[5].direction.angle()) < 0.001, "the additional scatter projectile travels down the center")
	_clear_projectiles()
	scatter_twin_effect.cleanup()

	var siege := SIEGE_CANNON.instantiate() as SiegeCannon
	add_child(siege)
	siege.set_process(false)
	var siege_twin_effect := _attach(twin, siege)
	siege.call("_spawn_strike", Vector2(300.0, 300.0))
	_check(get_tree().get_nodes_in_group(&"siege_airstrikes").size() == 2, "Twin Demon adds a second falling shell to Siege Cannon")
	for strike in get_tree().get_nodes_in_group(&"siege_airstrikes"):
		strike.free()
	siege_twin_effect.cleanup()

	var heavy_laser_entry := ModuleCatalog.get_entry(&"heavy_laser")
	_check(&"sturdy_stone" in heavy_laser_entry.get("artifact_incompatible_ids", []), "Sturdy Stone cannot be equipped to Heavy Laser")
	_check(&"twin_demon" in heavy_laser_entry.get("artifact_incompatible_ids", []), "Twin Demon cannot be equipped to Heavy Laser")

	gun.queue_free()
	cannon.queue_free()
	scatter.queue_free()
	siege.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("STURDY_STONE_TWIN_DEMON_TEST: PASS")
	else:
		for failure in failures:
			push_error("STURDY_STONE_TWIN_DEMON_TEST: " + failure)
	get_tree().quit(1 if not failures.is_empty() else 0)


func _attach(definition: MagicArtifactDefinition, weapon: WeaponModule) -> MagicArtifactEffect:
	var effect := definition.effect_script.new() as MagicArtifactEffect
	effect.configure(definition, null)
	effect.call("configure_weapon", weapon)
	add_child(effect)
	return effect


func _machine_gun_projectiles() -> Array[MachineGunProjectile]:
	var result: Array[MachineGunProjectile] = []
	for child in get_children():
		if child is MachineGunProjectile:
			result.append(child as MachineGunProjectile)
	return result


func _fusion_projectiles() -> Array[FusionProjectile]:
	var result: Array[FusionProjectile] = []
	for child in get_children():
		if child is FusionProjectile:
			result.append(child as FusionProjectile)
	return result


func _cannon_projectiles() -> Array[DwarfCannonProjectile]:
	var result: Array[DwarfCannonProjectile] = []
	for child in get_children():
		if child is DwarfCannonProjectile:
			result.append(child as DwarfCannonProjectile)
	return result


func _clear_projectiles() -> void:
	for child in get_children():
		if child is MachineGunProjectile or child is DwarfCannonProjectile or child is FusionProjectile:
			child.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
