extends Node

## Real base-entry and purchase gating against an isolated temporary save.
const TestSave := preload("res://Tests/TestSave.gd")
const BASE := preload("res://Scenes/Base/base_main.tscn")
var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func _run() -> void:
	TestSave.isolate("magic_shop_unlock_test")
	var definition := ArtifactManager.get_definition(&"amplifier")
	if definition == null:
		_check(false, "test shop artifact exists")
		_finish()
		return
	var old_price := definition.shop_price_ore
	definition.shop_price_ore = 10
	ResourceManager.stored_ore = 100.0
	_check(not ArtifactManager.is_shop_unlocked(), "new and old saves without Goblin clear keep shop locked")
	_check(not ArtifactManager.purchase_shop_artifact(&"amplifier"), "purchase API rejects uncompleted Goblin Planet")
	_check(not ArtifactManager.owns_artifact(&"amplifier") and is_equal_approx(ResourceManager.stored_ore, 100.0), "locked purchase gives no item and spends no ore")
	var base: Node = BASE.instantiate()
	add_child(base)
	await get_tree().process_frame
	var panel := base.get("magic_shop_panel") as Control
	base.call("open_magic_shop")
	_check(base.call("get_view_state_name") == &"OVERVIEW" and not panel.visible, "locked shop entrance stays in base overview")
	WeaponUnlockManager.record_planet_completion(&"goblin_planet")
	_check(ArtifactManager.is_shop_unlocked(), "Goblin Planet clear immediately unlocks shop")
	WeaponUnlockManager.reload_progress()
	_check(ArtifactManager.is_shop_unlocked(), "shop unlock survives saved progression reload")
	base.call("open_magic_shop")
	_check(base.call("get_view_state_name") == &"MAGIC_SHOP" and panel.visible, "shop opens at base after Goblin clear")
	base.call("close_magic_shop")
	_check(ArtifactManager.purchase_shop_artifact(&"amplifier"), "purchase API permits unlocked priced item")
	_check(ArtifactManager.owns_artifact(&"amplifier") and is_equal_approx(ResourceManager.stored_ore, 90.0), "unlocked purchase grants once and spends exact ore")
	ArtifactManager.reload_progress()
	_check(ArtifactManager.owns_artifact(&"amplifier"), "purchased artifact survives save reload")
	definition.shop_price_ore = old_price
	base.queue_free()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("MAGIC_SHOP_UNLOCK_TEST: PASS")
	else:
		for failure in failures:
			push_error("MAGIC_SHOP_UNLOCK_TEST FAIL: " + failure)
	get_tree().quit(1 if not failures.is_empty() else 0)
