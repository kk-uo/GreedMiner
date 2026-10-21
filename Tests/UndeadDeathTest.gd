extends Node

## Graveyard undead death effects play and free themselves; zombie graves
## pick one of the looks and rise after the sink effect (dwarves dig them up).

const UNDEAD_DEATH := preload("res://Scripts/VFX/UndeadDeath.gd")
const ZOMBIE_GRAVE := preload("res://Scripts/Battle/Graveyard/ZombieGrave.gd")

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var effects: Array = []
	for kind in [&"zombie", &"skeleton", &"vampire", &"werewolf"]:
		var fx := UNDEAD_DEATH.spawn(self, Vector2(100, 100), kind, 1.0, 0.5)
		_expect(fx != null, "%s effect spawned" % kind)
		effects.append(fx)
	var grave: Node2D = ZOMBIE_GRAVE.new()
	add_child(grave)
	var variant: int = grave.get("variant")
	_expect(variant >= 0 and variant < 6, "grave picked a look (%d)" % variant)
	await get_tree().create_timer(UNDEAD_DEATH.LIFE + 0.3).timeout
	for fx in effects:
		_expect(not is_instance_valid(fx), "effect freed itself after LIFE")
	_expect(not grave.has_method("register_click"), "graves can no longer be clicked away")
	grave.call("crumble")
	_expect(grave.is_queued_for_deletion(), "a dug-up grave crumbles away")
	if _failures.is_empty():
		print("UNDEAD_DEATH_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("UNDEAD_DEATH_TEST FAIL: " + failure)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
