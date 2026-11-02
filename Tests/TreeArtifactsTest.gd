extends Node2D

const TestSave := preload("res://Tests/TestSave.gd")
const GUN := preload("res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn")
const LASER := preload("res://Scenes/Modules/Weapons/Laser/laser.tscn")
const REGEN := preload("res://Scenes/Modules/Shield/regeneration_module.tscn")
const SHIP := preload("res://Scenes/Ship/ship.tscn")
const ROCK := preload("res://Scenes/Enemies/little_rock.tscn")
var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func _run() -> void:
	TestSave.isolate("tree_artifacts_test")
	var magnifier := ArtifactManager.get_definition(&"magnifying_glass")
	var soul := ArtifactManager.get_definition(&"treant_soul")
	var curse := ArtifactManager.get_definition(&"fairy_curse")
	_check(magnifier != null and soul != null and curse != null, "all three artifacts registered")
	if magnifier == null or soul == null or curse == null:
		_finish()
		return
	_check(magnifier.rarity == "Epic" and magnifier.shop_price_ore == -1 and not magnifier.mining_chest_reward, "magnifier is Epic, shop-only and not yet purchasable")
	_check(soul.rarity == "Rare" and curse.rarity == "Epic", "Tree artifact rarities")
	_check(curse.is_compatible_with_module(&"regeneration_module") and not curse.is_compatible_with_module(&"machine_gun"), "curse is healing-module-only")
	var tree_pool := ArtifactManager.get_unowned_mining_chest_artifacts(&"tree_planet")
	_check(tree_pool.has(soul) and tree_pool.has(curse) and not tree_pool.has(magnifier), "Tree chest pool includes only Tree drops")
	_check(not ArtifactManager.get_unowned_mining_chest_artifacts(&"rocky_planet").has(soul), "Tree drops excluded from Rocky chests")
	_check(ArtifactManager.grant_artifact(&"treant_soul"), "Tree Soul first grant")
	_check(not ArtifactManager.grant_artifact(&"treant_soul"), "Tree Soul globally unique")
	_check(not ArtifactManager.get_unowned_mining_chest_artifacts(&"tree_planet").has(soul), "owned Tree Soul excluded from chest pool")

	var gun := GUN.instantiate() as MachineGun
	gun.assembly_mode = true
	add_child(gun)
	var effect := soul.effect_script.new() as MagicArtifactEffect
	effect.configure(soul, null)
	effect.call("configure_weapon", gun)
	add_child(effect)
	var normal := gun.get_damage()
	var magnifier_effect := magnifier.effect_script.new() as MagicArtifactEffect
	magnifier_effect.configure(magnifier, null)
	magnifier_effect.call("configure_weapon", gun)
	add_child(magnifier_effect)
	_check(is_equal_approx(gun.get_modified_projectile_range(gun.projectile_range), gun.projectile_range * 2.0), "magnifier doubles projectile size without changing range")
	_check(is_equal_approx(gun.get_modified_attack_range(gun.attack_range), gun.attack_range), "magnifier does not change targeting range")
	magnifier_effect.cleanup()
	gun.enemy_defeated.emit(Vector2.ZERO, 20.0)
	gun.enemy_defeated.emit(Vector2.ZERO, 20.0)
	gun.begin_artifact_attack()
	_check(is_equal_approx(gun.get_damage(), normal * 2.0), "first kill boosts entire next attack")
	gun.end_artifact_attack()
	_check(is_equal_approx(gun.get_damage(), normal), "boost ends with attack")
	gun.begin_artifact_attack()
	_check(is_equal_approx(gun.get_damage(), normal * 2.0), "second kill stores another boosted attack")
	gun.end_artifact_attack()
	gun.begin_artifact_attack()
	_check(is_equal_approx(gun.get_damage(), normal), "no third boost without another kill")
	gun.enemy_defeated.emit(Vector2.ZERO, 20.0)
	gun.end_artifact_attack()
	gun.begin_artifact_attack()
	_check(is_equal_approx(gun.get_damage(), normal * 2.0), "kill during attack powers following attack")
	gun.end_artifact_attack()
	gun.enemy_defeated.emit(Vector2.ZERO, 20.0)
	gun.fire()
	var boosted_shot: MachineGunProjectile
	for child in get_children():
		if child is MachineGunProjectile:
			boosted_shot = child
			break
	_check(boosted_shot != null and is_equal_approx(boosted_shot.damage, normal * 2.0), "real machine-gun projectile snapshots doubled attack damage")
	if boosted_shot != null:
		boosted_shot.queue_free()
	effect.cleanup()
	_check(is_equal_approx(gun.get_damage(), normal), "effect cleanup removes damage provider")
	gun.queue_free()
	var laser := LASER.instantiate() as Laser
	laser.assembly_mode = true
	add_child(laser)
	var laser_glass := magnifier.effect_script.new() as MagicArtifactEffect
	laser_glass.configure(magnifier, null)
	laser_glass.call("configure_weapon", laser)
	add_child(laser_glass)
	_check(is_equal_approx(laser.get_effective_beam_width(), laser.beam_width * 10.0), "magnifier makes Laser beam tenfold")
	var prism := ArtifactManager.get_definition(&"demon_prism")
	var laser_prism := prism.effect_script.new() as MagicArtifactEffect
	laser_prism.configure(prism, null)
	laser_prism.call("configure_weapon", laser)
	add_child(laser_prism)
	_check(is_equal_approx(laser.get_effective_beam_width(), laser.beam_width * 10.0), "magnifier and prism together remain tenfold")
	laser._update_beam_length()
	_check(is_equal_approx(laser._beam.width, laser.beam_width * 10.0), "Laser visual follows tenfold collision width")
	laser_glass.cleanup()
	_check(is_equal_approx(laser.get_effective_beam_width(), laser.beam_width * 10.0), "remaining prism keeps tenfold width")
	laser_prism.cleanup()
	_check(is_equal_approx(laser.get_effective_beam_width(), laser.beam_width), "cleanup restores base Laser width")
	laser.queue_free()

	var regen := REGEN.instantiate() as RegenerationModule
	add_child(regen)
	regen.global_position = Vector2.ZERO
	var curse_effect := curse.effect_script.new() as MagicArtifactEffect
	curse_effect.configure(curse, null)
	curse_effect.call("configure_module", regen)
	add_child(curse_effect)
	var near := ROCK.instantiate() as BasicEnemy
	add_child(near)
	near.global_position = Vector2(35.0, 0.0)
	var far := ROCK.instantiate() as BasicEnemy
	add_child(far)
	far.global_position = Vector2(240.0, 0.0)
	await get_tree().physics_frame
	regen.ship_healed_by_pulse.emit(0.5, regen.global_position, 100.0)
	_check(is_equal_approx(float(near.get("_current_health")), near.max_health - 0.5), "actual healing mirrors damage to nearby enemy")
	_check(is_equal_approx(float(far.get("_current_health")), far.max_health), "enemy outside healing radius is untouched")
	curse_effect.cleanup()
	regen.ship_healed_by_pulse.emit(1.0, regen.global_position, 100.0)
	_check(is_equal_approx(float(near.get("_current_health")), near.max_health - 0.5), "unequipped curse causes no further damage")
	near.queue_free()
	far.queue_free()
	regen.queue_free()
	await get_tree().process_frame
	ResearchManager.progress.levels["shield_power.regeneration_module"] = 10
	ShipLoadout.install_module(1, 0, "res://Scenes/Modules/Shield/regeneration_module.tscn")
	_check(ShipLoadout.has_module(1, 0), "install Regeneration module")
	_check(ArtifactManager.grant_artifact(&"fairy_curse"), "Fairy Curse first grant")
	_check(ArtifactManager.equip_module_artifact(Vector2i(1, 0), &"fairy_curse"), "Fairy Curse equips to Regeneration")
	ArtifactManager.reload_progress()
	_check(ArtifactManager.owns_artifact(&"fairy_curse") and ArtifactManager.get_module_artifact(Vector2i(1, 0)) == &"fairy_curse", "Fairy Curse ownership and module slot survive save reload")
	var ship := SHIP.instantiate() as Ship
	add_child(ship)
	await get_tree().process_frame
	var installed_regen := ship.get_module_at(1, 0) as RegenerationModule
	_check(installed_regen != null, "installed Regeneration is present in battle")
	if installed_regen != null:
		ArtifactManager.attach_battle_effects(ship)
		var target := ROCK.instantiate() as BasicEnemy
		add_child(target)
		target.global_position = installed_regen.global_position + Vector2(20.0, 0.0)
		await get_tree().physics_frame
		ship.current_hp = ship.max_hp - 0.5
		var starting_hp: float = target.get("_current_health")
		installed_regen.apply_healing_pulse()
		_check(is_equal_approx(ship.current_hp, ship.max_hp), "Regeneration heals only missing ship HP")
		_check(is_equal_approx(float(target.get("_current_health")), starting_hp - 0.5), "equipped curse mirrors actual 0.5 HP pulse")
		ArtifactManager.clear_battle_effects(ship)
		target.queue_free()
	ship.queue_free()
	ShipLoadout.installed_modules.clear()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("TreeArtifactsTest PASS")
	else:
		for failure in failures:
			push_error("TREE_ARTIFACTS_TEST FAIL: " + failure)
	get_tree().quit(1 if not failures.is_empty() else 0)
