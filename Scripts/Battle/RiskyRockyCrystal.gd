extends "res://Scripts/Battle/RockyCrystal.gd"

## One optional Rocky Planet mine. Each completed mining segment pays ore;
## continuing to mine awakens another, larger group of Rock Golems.
signal golems_awakened(positions: Array[Vector2])

@export var stage_golems: PackedInt32Array = PackedInt32Array([1, 3, 5])
@export var stage_ore: PackedFloat32Array = PackedFloat32Array([30.0, 80.0, 160.0])
@export_range(0.0, 10.0, 0.1) var decision_seconds: float = 1.5

var _stage: int = 0
var _stage_started: bool = false
var _decision_left: float = 0.0
var _awakened_count: int = 0


func on_miner_arrived() -> void:
	if not can_be_mined() or _stage_started or _decision_left > 0.0 or _stage >= _stage_count():
		return
	_stage_started = true
	var positions: Array[Vector2] = []
	for index in range(stage_golems[_stage]):
		positions.append(to_global(_guard_offset(_awakened_count + index)))
	_awakened_count += positions.size()
	golems_awakened.emit(positions)
	queue_redraw()


func continues_after_reward() -> bool:
	return can_be_mined() and _stage < _stage_count()


func advance_mining(seconds: float) -> float:
	if not can_be_mined() or seconds <= 0.0 or _stage >= _stage_count():
		return 0.0
	if _decision_left > 0.0:
		_decision_left = maxf(0.0, _decision_left - seconds)
		if _decision_left == 0.0:
			on_miner_arrived()
		return 0.0
	if not _stage_started:
		on_miner_arrived()
	mining_progress += seconds
	queue_redraw()
	if mining_progress < ResearchManager.get_crystal_mining_seconds():
		return 0.0
	var reward := stage_ore[_stage] * ResearchManager.get_crystal_value_multiplier()
	_stage += 1
	mining_progress = 0.0
	_stage_started = false
	if _stage >= _stage_count():
		_broken = true
		queue_free()
	else:
		_decision_left = decision_seconds
	return reward


func _draw() -> void:
	super._draw()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Functional placeholder: distinguishes the optional high-risk deposit.
	draw_arc(Vector2.ZERO, 29.0 * _size, 0.0, TAU, 32, Color("ed7951"), 2.0)
	for index in range(_awakened_count, _guard_count()):
		var offset := _guard_offset(index)
		draw_circle(offset + Vector2(2.0, 4.0), 11.0, Color(0.0, 0.0, 0.0, 0.22))
		draw_circle(offset, 10.0, Color("69645d"))
		draw_circle(offset + Vector2(-3.0, -3.0), 3.0, Color("99948a"))


func _guard_offset(index: int) -> Vector2:
	return Vector2.RIGHT.rotated(-PI * 0.5 + TAU * float(index) / float(maxi(_guard_count(), 1))) * 90.0


func _stage_count() -> int:
	return mini(stage_golems.size(), stage_ore.size())


func _guard_count() -> int:
	var total := 0
	for index in range(_stage_count()):
		total += maxi(stage_golems[index], 0)
	return total
