extends Node

## Base only, presentation: the weapons installed on the docked ship look
## around instead of all pointing one way. Each turret turns to a random
## heading, holds it for a moment, then turns again (staggered per turret).
## Weapons stay in assembly mode (they never fire here); this only sets the
## local rotation of their "Turret" node. Load with preload(); no class_name.

const TURN_SPEED: float = 1.6  # rad/s
const HOLD_MIN: float = 0.8
const HOLD_MAX: float = 2.8

var ship: Ship
var _state: Dictionary = {}  # turret instance id -> {target, hold}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _process(delta: float) -> void:
	if not is_instance_valid(ship) or not is_instance_valid(ship.installed_modules):
		return
	var seen := {}
	for module in ship.installed_modules.get_children():
		if not module is WeaponModule:
			continue
		var turret := module.get_node_or_null("Turret") as Node2D
		if turret == null:
			continue
		var id := turret.get_instance_id()
		seen[id] = true
		if not _state.has(id):
			_state[id] = {"target": turret.rotation, "hold": _rng.randf_range(0.2, HOLD_MAX)}
		var entry: Dictionary = _state[id]
		if float(entry["hold"]) > 0.0:
			entry["hold"] = float(entry["hold"]) - delta
			if float(entry["hold"]) <= 0.0:
				# Next look: a decent turn either way, sometimes a full sweep.
				var swing := _rng.randf_range(0.6, 2.4) * (1.0 if _rng.randf() < 0.5 else -1.0)
				entry["target"] = wrapf(turret.rotation + swing, -PI, PI)
			continue
		var target: float = entry["target"]
		var remaining := angle_difference(turret.rotation, target)
		# Ease in/out: slow down over the last stretch of the turn.
		var speed := TURN_SPEED * clampf(absf(remaining) / 0.5, 0.25, 1.0)
		turret.rotation = rotate_toward(turret.rotation, target, speed * delta)
		if is_equal_approx(turret.rotation, target) or absf(angle_difference(turret.rotation, target)) < 0.01:
			entry["hold"] = _rng.randf_range(HOLD_MIN, HOLD_MAX)
	for id in _state.keys():
		if not seen.has(id):
			_state.erase(id)
