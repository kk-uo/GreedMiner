extends Node

## Verifies that fusion weapons inherit artifact compatibility from both
## ingredients and that shared runtime modifiers reach FusionWeapon attacks.

const SAVE := preload("res://Tests/TestSave.gd")
const SHIP_SCENE := preload("res://Scenes/Ship/ship.tscn")

var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SAVE.isolate("fusion_artifact_compatibility")
	ArtifactManager.set_equipment_changes_enabled(true)
	for artifact_id in [&"goblin_flag", &"demon_prism", &"angry_stone", &"ghost_bullet", &"red_crystal", &"necronomicon", &"snow_monster_eyeball"]:
		_check(ArtifactManager.grant_artifact(artifact_id), "grant %s" % artifact_id)
	_check(ArtifactManager.get_definition(&"goblin_glove") == null, "retired Goblin Glove is absent from the artifact registry")

	var cell := Vector2i(0, 0)
	for recipe in WeaponFusionRegistry.RECIPES:
		var result_id := StringName(recipe["result_id"])
		var scene_path := String(recipe["scene"])
		var definition := ResearchManager.get_weapon_research_definition(result_id)
		if definition != null:
			ResearchManager.progress.levels[String(definition.research_id)] = 30
		ShipLoadout.install_module(cell.x, cell.y, scene_path)
		_check(ArtifactManager.get_module_artifact_slot_count(cell) == 3, "%s has three artifact slots at Level 30" % result_id)
		_check(ArtifactManager.equip_module_artifact(cell, &"goblin_flag", 0), "%s accepts universal weapon artifact" % result_id)
		_check(ArtifactManager.is_module_artifact_compatible(cell, &"necronomicon"), "%s accepts Necronomicon" % result_id)
		_check(ArtifactManager.is_module_artifact_compatible(cell, &"snow_monster_eyeball"), "%s accepts Snow Monster Eyeball" % result_id)
		var entry := ModuleCatalog.get_entry(result_id)
		var inherited_ids: Array = entry.get("artifact_compatibility_ids", [])
		var prism_definition := ArtifactManager.get_definition(&"demon_prism")
		var prism_allowed: bool = false
		for ingredient_id in inherited_ids:
			if prism_definition != null and prism_definition.is_compatible_with_module(StringName(ingredient_id)):
				prism_allowed = true
				break
		if &"demon_prism" in entry.get("artifact_incompatible_ids", []):
			prism_allowed = false
		_check(ArtifactManager.equip_module_artifact(cell, &"demon_prism", 1) == prism_allowed, "%s projectile-size compatibility is explicit" % result_id)
		ArtifactManager.unequip_module_artifact(cell, 0)
		ArtifactManager.unequip_module_artifact(cell, 1)

		var inherited: Array = inherited_ids
		var excluded: Array = entry.get("artifact_incompatible_ids", [])
		for artifact_id in [&"angry_stone", &"ghost_bullet", &"red_crystal"]:
			var artifact := ArtifactManager.get_definition(artifact_id)
			var expected := false
			for ingredient_id in inherited:
				if artifact != null and artifact.is_compatible_with_module(StringName(ingredient_id)):
					expected = true
					break
			if artifact_id in excluded:
				expected = false
			var equipped := ArtifactManager.equip_module_artifact(cell, artifact_id, 0) if expected else ArtifactManager._is_valid_module_assignment(cell, artifact_id)
			_check(equipped == expected, "%s compatibility is inherited correctly by %s" % [artifact_id, result_id])
			if equipped:
				ArtifactManager.unequip_module_artifact(cell, 0)

	# Exercise the shared providers on a real runtime fusion weapon.
	var scatter_id := &"scatter_machine_gun"
	var scatter_scene := String(ModuleCatalog.get_entry(scatter_id).get("scene", ""))
	ShipLoadout.install_module(cell.x, cell.y, scatter_scene)
	_check(ArtifactManager.equip_module_artifact(cell, &"goblin_flag", 0), "equip fire-rate artifact on fusion weapon")
	_check(ArtifactManager.equip_module_artifact(cell, &"demon_prism", 1), "equip range artifact on fusion weapon")
	_check(ArtifactManager.equip_module_artifact(cell, &"ghost_bullet", 2), "equip projectile artifact on fusion weapon")
	var ship := SHIP_SCENE.instantiate() as Ship
	add_child(ship)
	await get_tree().process_frame
	var weapon := ship.get_module_at(cell.x, cell.y) as FusionWeapon
	_check(weapon != null, "runtime fusion weapon exists")
	if weapon != null:
		var base_rate := 0.0 if weapon.attack_interval <= 0.0 else 1.0 / weapon.attack_interval
		ArtifactManager.attach_battle_effects(ship)
		_check(is_equal_approx(weapon.get_fire_rate(), base_rate * 1.25), "fire-rate artifact modifies fusion weapon")
		_check(is_equal_approx(weapon.get_modified_attack_range(weapon.attack_range), weapon.attack_range), "Demon Prism leaves fusion targeting range unchanged")
		_check(is_equal_approx(weapon.get_modified_projectile_range(weapon.projectile_range), weapon.projectile_range * 2.0), "Demon Prism modifies fusion projectile size")
		_check(weapon.get_artifact_projectile_pierces() == 1, "Ghost Bullet provider reaches fusion weapon")
		weapon._fire_projectiles()
		await get_tree().process_frame
		var projectile := _find_fusion_projectile()
		_check(projectile != null and projectile._ghost != null, "FusionWeapon transfers Ghost Bullet state to spawned projectiles")
		ArtifactManager.clear_battle_effects(ship)

	ship.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("FUSION_ARTIFACT_COMPATIBILITY_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("FUSION_ARTIFACT_COMPATIBILITY_TEST: " + failure)
		get_tree().quit(1)


func _find_fusion_projectile() -> FusionProjectile:
	return _find_fusion_projectile_below(get_tree().root)


func _find_fusion_projectile_below(node: Node) -> FusionProjectile:
	for child in node.get_children():
		if child is FusionProjectile:
			return child as FusionProjectile
		var nested := _find_fusion_projectile_below(child)
		if nested != null:
			return nested
	return null


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
