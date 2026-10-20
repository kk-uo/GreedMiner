class_name SalvageDiscoveryEvent
extends MiningQteEvent

## QTE 3 — Salvage Discovery. The Mining Module digs up a salvage crate that
## pops out of the module and lands just outside the hull. It waits for
## salvage_lifetime seconds (blinking near the end); clicking it opens it and
## grants either a registered unowned artifact or the mining reward at once.

enum Phase { POP, WAIT, OPEN, FADE }

const POP_TIME: float = 0.7
const OPEN_TIME: float = 0.9
const CLICK_RADIUS: float = 28.0
## Landing distance from the ship centre (outside the hull even at 45°).
const LANDING_DISTANCE: float = 160.0

var landing_position: Vector2

var _phase: int = Phase.POP
var _phase_age: float = 0.0
var _age: float = 0.0
var _start_position: Vector2
var _shards: Array[Dictionary] = []
var _artifact_awarded: bool = false


func _on_begin() -> void:
	_start_position = get_module_position()
	var ship_center := _start_position
	if manager != null and is_instance_valid(manager.ship):
		ship_center = manager.ship.to_global(Ship.SHIP_SIZE * 0.5)
	var direction := _start_position - ship_center
	if direction.length() < 4.0:
		direction = Vector2.RIGHT.rotated(randf() * TAU)
	direction = direction.normalized().rotated(randf_range(-0.5, 0.5))
	landing_position = ship_center + direction * LANDING_DISTANCE
	global_position = landing_position


## Lifetime left on the ground (seconds).
func get_time_left() -> float:
	if _phase == Phase.POP:
		return config.salvage_lifetime
	if _phase == Phase.WAIT:
		return maxf(config.salvage_lifetime - _phase_age, 0.0)
	return 0.0


func is_waiting() -> bool:
	return _phase == Phase.WAIT and not is_resolved()


func _process(delta: float) -> void:
	_age += delta
	_phase_age += delta
	match _phase:
		Phase.POP:
			if _phase_age >= POP_TIME:
				_set_phase(Phase.WAIT)
		Phase.WAIT:
			if _phase_age >= config.salvage_lifetime:
				resolve(OUTCOME_EXPIRED)
		Phase.OPEN:
			var drag: float = exp(-4.0 * delta)
			for shard in _shards:
				shard["vel"] *= drag
				shard["pos"] += shard["vel"] * delta
				shard["rot"] += shard["spin"] * delta
			if _phase_age >= OPEN_TIME + 0.5:
				queue_free()
		Phase.FADE:
			if _phase_age >= 0.4:
				queue_free()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not is_waiting():
		return
	if _consume_click(event, global_position, CLICK_RADIUS):
		open()


## Same as clicking the crate. Only works once it has landed.
func open() -> void:
	if not is_waiting():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for index in range(10):
		var angle: float = -PI * 0.5 + rng.randf_range(-1.3, 1.3)
		_shards.append({
			"pos": Vector2.ZERO,
			"vel": Vector2.RIGHT.rotated(angle) * rng.randf_range(80.0, 170.0),
			"rot": angle,
			"spin": rng.randf_range(-7.0, 7.0),
		})
	_set_phase(Phase.OPEN)
	var candidates := ArtifactManager.get_unowned_mining_chest_artifacts()
	if not candidates.is_empty() and rng.randf() < clampf(config.salvage_artifact_chance, 0.0, 1.0):
		var selected := candidates[rng.randi_range(0, candidates.size() - 1)]
		_artifact_awarded = ArtifactManager.grant_artifact(selected.artifact_id)
	resolve(OUTCOME_SUCCESS)


func _reward_for(result: StringName) -> float:
	if _artifact_awarded or result != OUTCOME_SUCCESS:
		return 0.0
	return MiningQteManager.calculate_reward(module, config)


func _on_resolved(result: StringName) -> void:
	match result:
		OUTCOME_SUCCESS:
			pass
		OUTCOME_EXPIRED:
			_set_phase(Phase.FADE)
		_:
			queue_free()


func _set_phase(phase: int) -> void:
	_phase = phase
	_phase_age = 0.0


func _draw() -> void:
	var glow: float = 0.5 + 0.5 * sin(_age * 4.0)
	match _phase:
		Phase.POP:
			var k: float = clampf(_phase_age / POP_TIME, 0.0, 1.0)
			var ground: Vector2 = (_start_position - landing_position).lerp(Vector2.ZERO, k)
			var height: float = sin(k * PI) * 46.0
			draw_circle(ground + Vector2(4.0, 6.0), 10.0 * (0.6 + 0.4 * k), Color(0, 0, 0, 0.2))
			MiningQteVisual.draw_chest(self, ground - Vector2(0.0, height), 0.0, glow, lerpf(0.55, 1.0, k) * (1.0 + 0.25 * sin(k * PI)))
		Phase.WAIT:
			var left: float = config.salvage_lifetime - _phase_age
			var alpha: float = 1.0
			if left < 5.0:
				alpha = 0.45 + 0.55 * absf(cos(_phase_age * (5.0 if left > 2.0 else 10.0)))
			var land_bounce: float = maxf(0.0, 1.0 - _phase_age / 0.25)
			draw_circle(Vector2.ZERO, 28.0, Color(Palette.GOLD, 0.12 * glow * alpha))
			MiningQteVisual.draw_chest(self, Vector2(0.0, -2.0 * land_bounce), 0.0, glow, 1.0 + 0.08 * land_bounce, alpha)
			# Lifetime ring under the crate.
			draw_arc(Vector2.ZERO, 30.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(left / config.salvage_lifetime, 0.0, 1.0), 40, Color(Palette.GOLD_LIGHT, 0.6 * alpha), 2.0)
		Phase.OPEN:
			var k: float = clampf(_phase_age / 0.25, 0.0, 1.0)
			var fade: float = clampf((OPEN_TIME + 0.5 - _phase_age) / 0.4, 0.0, 1.0)
			if _phase_age < 0.4:
				var ring: float = _phase_age / 0.4
				draw_arc(Vector2.ZERO, 14.0 + 30.0 * ring, 0.0, TAU, 32, Color(Palette.GOLD_LIGHT, 1.0 - ring), 2.5)
			MiningQteVisual.draw_chest(self, Vector2.ZERO, k, 1.0, 1.0, fade)
			for shard in _shards:
				MiningQteVisual.draw_shard(self, shard["pos"], 1.0, shard["rot"], fade)
		Phase.FADE:
			MiningQteVisual.draw_chest(self, Vector2(0.0, 3.0 * _phase_age / 0.4), 0.0, 0.0, 1.0 - 0.3 * _phase_age / 0.4, 1.0 - _phase_age / 0.4)
