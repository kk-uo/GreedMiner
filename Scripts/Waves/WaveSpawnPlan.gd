class_name WaveSpawnPlan
extends RefCounted

## Validated, quota-preserving runtime plan produced before a wave begins.

var requests: Array[WaveSpawnRequest] = []
var timed_requests: Array[WaveSpawnRequest] = []
var quota_by_enemy_id: Dictionary = {}
var special_events: Array[Dictionary] = []
var validation_errors: Array[String] = []
var total_spawn_count: int = 0
var total_spawn_budget: int = 0
## Non-zero only when SINGLE_DIRECTION selected one shared edge for this wave.
var selected_direction: Vector2 = Vector2.ZERO


func get_planned_count(enemy_id: StringName) -> int:
	return int(quota_by_enemy_id.get(String(enemy_id), 0))
