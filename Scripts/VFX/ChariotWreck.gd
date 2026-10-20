extends Node2D

## Goblin Giant Chariot defeat animation (presentation only, frees itself).
## The wagon bursts into debris, the crew goblins and both war boars scatter
## away from the ship in a panic, then a white flag slowly rises out of the
## wreck and waves until everything fades.
## Spawned by GoblinGiantChariot._perform_death_effect via setup().

const LIFE: float = 9.0
const FADE_TIME: float = 1.2
const FLAG_START: float = 1.3
const FLAG_RISE_TIME: float = 2.8

## Crew that jumps off the wagon (chariot base frame). First one is the chieftain.
const CREW: Array[Vector2] = [
	Vector2(-16, 0), Vector2(-114, -15), Vector2(-102, -7), Vector2(-115, 2), Vector2(-102, 10),
	Vector2(-111, 19), Vector2(-80, -30), Vector2(-46, 28), Vector2(-70, 18),
]

var facing: float = 0.0

var _age: float = 0.0
var _pieces: Array = []
var _puffs: Array[Dictionary] = []
var _flag_base := Vector2.ZERO
var _rng := RandomNumberGenerator.new()


## Call before adding to the tree.
func setup(chariot_facing: float, rng_seed: int = 0) -> void:
	facing = chariot_facing
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()


func _ready() -> void:
	_pieces = GoblinVisual.build_chariot_wreck(_rng)
	# The flag comes out of the middle chunk where it settles.
	_flag_base = (GoblinVisual.wreck_rest_position(_pieces[1]) * GoblinVisual.CHARIOT_SCALE).rotated(facing)
	for index in range(14):
		_puffs.append({
			"dir": Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU)),
			"from": (Vector2(_rng.randf_range(-120.0, 0.0), _rng.randf_range(-40.0, 40.0)) * GoblinVisual.CHARIOT_SCALE).rotated(facing),
			"speed": _rng.randf_range(30.0, 80.0),
			"size": _rng.randf_range(14.0, 26.0),
			"delay": _rng.randf_range(0.0, 0.35),
			"life": _rng.randf_range(1.0, 1.7),
		})
	_spawn_runners()


func _spawn_runners() -> void:
	var away: float = facing + PI
	var count: int = CREW.size()
	for index in range(count):
		var runner := Runner.new()
		runner.kind = Runner.Kind.CHIEF if index == 0 else Runner.Kind.GOBLIN
		var fan: float = lerpf(-1.5, 1.5, float(index) / float(count - 1)) + _rng.randf_range(-0.15, 0.15)
		runner.dir = Vector2.RIGHT.rotated(away + fan)
		runner.start = (CREW[index] * GoblinVisual.CHARIOT_SCALE).rotated(facing)
		runner.speed = _rng.randf_range(150.0, 200.0) * (0.85 if index == 0 else 1.0)
		runner.delay = 0.08 + _rng.randf_range(0.0, 0.3)
		runner.phase = _rng.randf_range(0.0, TAU)
		add_child(runner)
	for side in [-1.0, 1.0]:
		var boar := Runner.new()
		boar.kind = Runner.Kind.BOAR
		boar.dir = Vector2.RIGHT.rotated(facing + side * 1.95)
		boar.start = (Vector2(68.0, side * 30.0) * GoblinVisual.CHARIOT_SCALE).rotated(facing)
		boar.speed = 240.0
		boar.delay = 0.05
		boar.phase = 0.7 if side > 0.0 else 0.0
		add_child(boar)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	modulate.a = clampf((LIFE - _age) / FADE_TIME, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	GoblinVisual.draw_chariot_wreck(self, facing, _pieces, _age)
	# Dust and smoke from the crash.
	for puff in _puffs:
		var t: float = _age - float(puff["delay"])
		var life: float = puff["life"]
		if t <= 0.0 or t >= life:
			continue
		var k: float = t / life
		var pos: Vector2 = puff["from"] + puff["dir"] * float(puff["speed"]) * t + Vector2(0.0, -18.0 * k)
		var radius: float = float(puff["size"]) * (0.6 + 0.8 * k)
		draw_circle(pos, radius, Color(0.33, 0.31, 0.28, 0.5 * (1.0 - k)))
		draw_circle(pos + Vector2(-radius * 0.25, -radius * 0.25), radius * 0.6, Color(0.5, 0.47, 0.42, 0.4 * (1.0 - k)))
	var rise: float = clampf((_age - FLAG_START) / FLAG_RISE_TIME, 0.0, 1.0)
	GoblinVisual.draw_surrender_flag(self, _flag_base, rise, _age)


## One panicking goblin / boar running off; fades and frees itself.
class Runner extends Node2D:
	enum Kind { GOBLIN, CHIEF, BOAR }
	const JUMP_TIME: float = 0.35
	const RUN_TIME: float = 2.6
	const FADE: float = 0.7

	var kind: Kind = Kind.GOBLIN
	var dir := Vector2.RIGHT
	var start := Vector2.ZERO
	var speed: float = 170.0
	var delay: float = 0.0
	var phase: float = 0.0

	var _t: float = 0.0
	var _lift: float = 1.0
	var _step: float = 0.0

	func _ready() -> void:
		position = start
		visible = kind == Kind.BOAR

	func _process(delta: float) -> void:
		_t += delta
		var s: float = _t - delay
		if s < 0.0:
			return
		visible = true
		if s > RUN_TIME + FADE:
			queue_free()
			return
		var perp := Vector2(-dir.y, dir.x)
		var jump_end: Vector2 = start + dir * 34.0
		if kind != Kind.BOAR and s < JUMP_TIME:
			var k: float = s / JUMP_TIME
			position = start.lerp(jump_end, k)
			_lift = 1.0 + 0.45 * sin(PI * k)
		else:
			var run: float = s - (0.0 if kind == Kind.BOAR else JUMP_TIME)
			var from: Vector2 = start if kind == Kind.BOAR else jump_end
			var zig: float = 0.0 if kind == Kind.BOAR else sin(run * 7.0 + phase) * 7.0
			position = from + dir * speed * run * (0.6 + 0.4 * minf(run / 0.4, 1.0)) + perp * zig
			_lift = 1.0
		_step = sin(s * (14.0 if kind == Kind.BOAR else 22.0) + phase)
		modulate.a = clampf((RUN_TIME + FADE - s) / FADE, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		var angle: float = dir.angle()
		match kind:
			Kind.BOAR:
				GoblinVisual.draw_war_boar(self, angle, _step, _t)
			Kind.CHIEF:
				GoblinVisual.draw_elite(self, angle, _step, 0.0, false)
			_:
				GoblinVisual.draw_goblin(self, angle, _step, 0.0, false, false, Vector2.ZERO, _lift)
		if kind == Kind.BOAR:
			return
		# Panic sweat drops flicking off behind the head.
		var bob: float = absf(_step)
		var back: Vector2 = -dir * 10.0
		for index in range(2):
			var drop: Vector2 = back + Vector2(-6.0 + index * 12.0, -16.0 - bob * 5.0 - index * 3.0)
			draw_circle(drop, 2.6, Color("BFE6FF"))
			draw_colored_polygon(PackedVector2Array([drop + Vector2(-2.4, 0.5), drop + Vector2(0.0, -6.0), drop + Vector2(2.4, 0.5)]), Color("BFE6FF"))
