extends Node2D

## A short beat between the end of a battle and the result panel, so the
## screen does not jump straight to it (BattleMain awaits play()):
## - victory: the game slows down for a moment, a cream ring sweeps out from
##   the ship and the world settles; ~1.6 s.
## - defeat:  slow motion, a chain of blasts round the hull, the camera
##   shakes, the ship darkens and smokes; ~2.2 s.
## Uses real time (ignores Engine.time_scale) and always restores the time
## scale and camera, also if the scene is left early. World space, at the
## ship's centre. Load with preload(); no class_name on purpose.

const VICTORY_TIME: float = 1.6
const DEFEAT_TIME: float = 2.2
const SLOW_SCALE: float = 0.35
const RING := Color("FBF3E4")
const SMOKE := Color("2E2621")

## The running beat (DeveloperBattleSpeed leaves Engine.time_scale alone
## while one is active, like for BossFinisher).
static var _active: Node = null

var kind: StringName = &"victory"
var ship: Node2D = null
var _age: float = 0.0
var _camera: Camera2D = null
var _camera_offset := Vector2.ZERO
var _smoke: Array = []
var _reach: float = 120.0


## Plays the beat for `outcome` (&"victory" / &"defeat") at the ship and
## returns when the result panel may show.
static func play(parent: Node, battle_ship: Node2D, outcome: StringName) -> void:
	var beat: Node2D = load("res://Scripts/VFX/BattleEndBeat.gd").new()
	beat.kind = outcome
	beat.ship = battle_ship
	beat.z_index = 30
	parent.add_child(beat)
	await beat.finished


signal finished


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ship != null and is_instance_valid(ship):
		global_position = ship.call("get_healing_position") if ship.has_method("get_healing_position") else ship.global_position
		var size: Vector2 = ship.get("SHIP_SIZE") if ship.get("SHIP_SIZE") != null else Vector2(192, 192)
		_reach = size.length() * 0.5
		_camera = ship.get("world_camera") as Camera2D
		if _camera != null:
			_camera_offset = _camera.offset
	_active = self
	Engine.time_scale = SLOW_SCALE
	if kind == &"defeat":
		_defeat_sequence()
	else:
		_victory_sequence()


func _exit_tree() -> void:
	if _active == self:
		_active = null
	Engine.time_scale = 1.0
	if _camera != null and is_instance_valid(_camera):
		_camera.offset = _camera_offset


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _victory_sequence() -> void:
	await _wait(0.55)
	_ease_time_back(0.4)
	await _wait(VICTORY_TIME - 0.55)
	_finish()


func _defeat_sequence() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if ship != null and is_instance_valid(ship):
		var dim := create_tween().set_ignore_time_scale(true)
		dim.tween_property(ship, "modulate", Color(0.42, 0.37, 0.34), 1.2).set_delay(0.3)
	for index in range(7):
		var at := global_position + Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(0.15, 0.85) * _reach
		FlatBurst.spawn(get_parent(), at, rng.randf_range(44.0, 70.0), Palette.SHOT, Color("2E2621"))
		_smoke.append({"at": at - global_position, "born": _age, "r": rng.randf_range(22.0, 34.0)})
		await _wait(0.16)
	_ease_time_back(0.5)
	await _wait(DEFEAT_TIME - 7.0 * 0.16)
	_finish()


func _ease_time_back(seconds: float) -> void:
	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_method(func(v: float) -> void: Engine.time_scale = v, Engine.time_scale, 1.0, seconds)


func _finish() -> void:
	if _active == self:
		_active = null
	Engine.time_scale = 1.0
	if _camera != null and is_instance_valid(_camera):
		_camera.offset = _camera_offset
	finished.emit()
	# Smoke keeps rising behind the result panel, then the node goes.
	var fade := create_tween().set_ignore_time_scale(true)
	fade.tween_property(self, "modulate:a", 0.0, 1.5)
	fade.tween_callback(queue_free)


func _process(_delta: float) -> void:
	_age += get_process_delta_time() / maxf(Engine.time_scale, 0.01)
	if kind == &"defeat" and _camera != null and is_instance_valid(_camera):
		var shake := 9.0 * clampf(1.0 - _age / 1.6, 0.0, 1.0)
		_camera.offset = _camera_offset + Vector2(sin(_age * 71.0), cos(_age * 53.0)) * shake
	queue_redraw()


func _draw() -> void:
	if kind == &"victory":
		for ring in range(2):
			var t := clampf((_age - 0.15 * float(ring)) / 0.9, 0.0, 1.0)
			if t > 0.0 and t < 1.0:
				var e := 1.0 - pow(1.0 - t, 3.0)
				draw_arc(Vector2.ZERO, _reach * (0.9 + 1.8 * e), 0.0, TAU, 64, Color(RING, 0.55 * (1.0 - t)), 10.0 * (1.0 - t) + 2.0)
		return
	# Defeat: smoke puffs rising from each blast.
	for puff in _smoke:
		for k in range(3):
			var t := fposmod(_age - float(puff["born"]) - 0.3 * float(k), 1.4) / 1.4
			var p: Vector2 = puff["at"] + Vector2(6.0 * sin(t * 5.0 + float(k)), -60.0 * t)
			draw_circle(p, float(puff["r"]) * (0.6 + 0.8 * t), Color(SMOKE, 0.65 * (1.0 - t)))
