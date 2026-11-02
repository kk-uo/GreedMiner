extends Node

const TestSave := preload("res://Tests/TestSave.gd")
const CONFIG := preload("res://Resources/Artifacts/ArtifactConfiguration.tres")
const Weapon := preload("res://Scripts/Modules/Weapons/WeaponModule.gd")
const Effect := preload("res://Scripts/Artifacts/WeaponStatArtifactEffect.gd")
const ShopPanel := preload("res://Scripts/UI/MagicShopPanel.gd")


var _failures: int = 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	TestSave.isolate("magic_shop_projectile_speed_test")
	_assert(not ArtifactManager.is_shop_unlocked(), "fresh save starts with the shop locked")
	WeaponUnlockManager.record_planet_completion(&"goblin_planet")
	_assert(ArtifactManager.is_shop_unlocked(), "Goblin Planet clear unlocks shop before price checks")
	_assert(CONFIG.get_validation_errors().is_empty(), "artifact registry must be valid")
	var ids: Array[StringName] = [&"slow_hourglass", &"fast_hourglass", &"amplifier", &"heavy_shell", &"magnifying_glass"]
	for id in ids:
		var definition: MagicArtifactDefinition = CONFIG.get_definition(id)
		_assert(definition != null, "%s must be registered" % id)
		_assert(definition.get_acquisition_method() == MagicArtifactDefinition.AcquisitionMethod.SHOP, "%s must be shop-only" % id)
		_assert(definition.shop_price_ore == -1, "%s price must remain TBD" % id)
		_assert(not definition.mining_chest_reward, "%s must not enter mining chests" % id)
	_assert(ArtifactManager.get_shop_artifacts().size() == 5, "shop must list five configured products")
	var panel: MagicShopPanel = ShopPanel.new()
	get_tree().root.add_child(panel)
	panel.open_panel()
	# Claude sync 99: rug-stall shop, one card per product and one coin button.
	var cards: Array = panel.get_item_cards()
	_assert(cards.size() == 5, "shop UI must display all five products")
	for index in range(cards.size()):
		panel.select_item(index)
		var button: Button = panel.get_buy_button()
		_assert(button.disabled and button.text == tr("PRICE TBD"), "unpriced item button must be disabled")
	panel.queue_free()
	_assert(not CONFIG.get_definition(&"heavy_shell").is_compatible_with_module(&"laser"), "heavy shells must not fit lasers")
	_assert(not CONFIG.get_definition(&"heavy_shell").inherit_fusion_compatibility, "heavy shells require explicit cannon compatibility")

	var weapon: WeaponModule = Weapon.new()
	weapon.weapon_type_id = &"shop_speed_test"
	get_tree().root.add_child(weapon)
	var slow := _equip(weapon, &"slow_hourglass")
	_assert(is_equal_approx(weapon.get_modified_projectile_speed(400.0), 200.0), "slow hourglass must halve projectile speed")
	var fast := _equip(weapon, &"fast_hourglass")
	_assert(is_equal_approx(weapon.get_modified_projectile_speed(400.0), 300.0), "speed multipliers must multiply to 0.75")
	slow.cleanup()
	_assert(is_equal_approx(weapon.get_modified_projectile_speed(400.0), 600.0), "unequipping slow must remove only its modifier")
	fast.cleanup()
	_assert(is_equal_approx(weapon.get_modified_projectile_speed(400.0), 400.0), "unequipping both must restore base speed")

	var amplifier := _equip(weapon, &"amplifier")
	_assert(is_equal_approx(weapon.get_modified_damage(10.0), 11.0), "amplifier must add one flat final damage")
	amplifier.cleanup()
	var heavy := _equip(weapon, &"heavy_shell")
	_assert(is_equal_approx(weapon.get_modified_damage(20.0), 25.0), "heavy shell must increase damage by 25%")
	_assert(is_equal_approx(weapon.get_modified_projectile_speed(400.0), 200.0), "heavy shell must halve shell speed")
	heavy.cleanup()
	_assert(is_equal_approx(weapon.get_modified_projectile_speed(400.0), 400.0), "heavy shell cleanup must restore speed")

	var ore_before := ResourceManager.stored_ore
	_assert(not ArtifactManager.purchase_shop_artifact(&"slow_hourglass"), "unpriced item must not be purchasable")
	_assert(ResourceManager.stored_ore == ore_before, "unpriced attempt must not deduct ore")
	weapon.queue_free()
	if _failures == 0:
		print("MAGIC SHOP AND PROJECTILE SPEED TEST PASSED")
	get_tree().quit(0 if _failures == 0 else 1)


func _equip(weapon: WeaponModule, id: StringName) -> MagicArtifactEffect:
	var effect: MagicArtifactEffect = Effect.new()
	effect.configure(CONFIG.get_definition(id), null)
	effect.configure_weapon(weapon)
	weapon.add_child(effect)
	return effect


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
