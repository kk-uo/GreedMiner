extends RefCounted

## Each projectile tracks its own hits and remaining penetrations.
var remaining: int
var hit_ids: Dictionary = {}

func _init(initial_pierces: int) -> void:
	remaining = maxi(initial_pierces, 0)

func register_target(enemy: BasicEnemy) -> bool:
	var id := enemy.get_instance_id()
	if hit_ids.has(id):
		return false
	hit_ids[id] = true
	return true

func continue_after_hit(killed: bool) -> bool:
	if killed:
		remaining += 1
	if remaining <= 0:
		return false
	remaining -= 1
	return true
