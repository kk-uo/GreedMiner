extends Node2D

## A small volcanic vent on the Volcanic Planet battlefield that keeps oozing
## lava: a low dark cone with a bubbling pool, lava spilling over its lip and
## embers rising. Click it CLICKS_TO_ERUPT times and it erupts: a lava
## fountain and a fiery shockwave dealing ERUPT_DAMAGE to every enemy within
## ERUPT_RADIUS. Afterwards it rests for COOLDOWN seconds (dim, not
## clickable), then can be primed again.
##
## Battlefield places these (lava theme, interactive_lava_vents) at the old
## crater spots; BattleMain routes clicks through Battlefield.try_click_vent().
## Load with preload(); no class_name on purpose.

signal erupted(world_position: Vector2, enemies_hit: int)

const CLICKS_TO_ERUPT: int = 5
const ERUPT_DAMAGE: float = 50.0
const ERUPT_RADIUS: float = 110.0
const COOLDOWN: float = 4.0
const RADIUS: float = 20.0
const CLICK_RADIUS: float = 32.0
const ERUPT_TIME: float = 1.1

const ROCK_DARK := Color("2A1F1C")
const ROCK := Color("4A3830")
const ROCK_LIGHT := Color("6E5548")
const CRUST := Color("3B1712")
const LAVA_DARK := Color("C2410C")
const LAVA := Color("FF7A1A")
const LAVA_HOT := Color("FFC061")
const LAVA_CORE := Color("FFF1B0")

var clicks: int = 0
var _time: float = 0.0
var _cooldown: float = 0.0
var _erupt_age: float = -1.0
var _jolt: float = 0.0
var _turn: float = 0.0
var _drips: Array = []  # lava oozing over the lip
var _blobs: Array = []  # eruption fountain
var _splats: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_time = _rng.randf() * 10.0
	_turn = _rng.randf() * TAU
	for k in range(3):
		_drips.append({"angle": _turn + TAU * float(k) / 3.0 + _rng.randf_range(-0.4, 0.4), "phase": _rng.randf(), "speed": _rng.randf_range(0.22, 0.35)})


func contains_world_point(point: Vector2) -> bool:
	return global_position.distance_to(point) <= CLICK_RADIUS


func is_ready_to_click() -> bool:
	return _cooldown <= 0.0 and _erupt_age < 0.0


## One player click: builds pressure; the CLICKS_TO_ERUPT-th click erupts.
func register_click() -> bool:
	if not is_ready_to_click():
		return false
	clicks += 1
	_jolt = 1.0
	if clicks >= CLICKS_TO_ERUPT:
		_erupt()
	return true


func _erupt() -> void:
	clicks = 0
	_erupt_age = 0.0
	_cooldown = COOLDOWN
	var hit := 0
	if is_inside_tree():
		for node in get_tree().get_nodes_in_group("enemies"):
			var enemy := node as BasicEnemy
			if enemy == null or enemy.is_dying():
				continue
			if enemy.global_position.distance_to(global_position) <= ERUPT_RADIUS + enemy.get_collision_radius():
				enemy.take_damage(ERUPT_DAMAGE)
				hit += 1
	for k in range(16):
		var dir := Vector2.RIGHT.rotated(_rng.randf() * TAU)
		_blobs.append({"vel": dir * _rng.randf_range(30.0, ERUPT_RADIUS * 0.9), "vz": _rng.randf_range(180.0, 320.0), "pos": Vector2.ZERO, "z": 0.0, "r": _rng.randf_range(2.5, 5.0), "landed": false})
	erupted.emit(global_position, hit)


func _process(delta: float) -> void:
	_time += delta
	_jolt = maxf(_jolt - delta * 5.0, 0.0)
	if _cooldown > 0.0:
		_cooldown -= delta
	if _erupt_age >= 0.0:
		_erupt_age += delta
		if _erupt_age > ERUPT_TIME:
			_erupt_age = -1.0
	for blob in _blobs:
		if blob["landed"]:
			continue
		blob["pos"] += blob["vel"] * delta
		blob["z"] += blob["vz"] * delta
		blob["vz"] -= 700.0 * delta
		if blob["z"] <= 0.0:
			blob["landed"] = true
			_splats.append({"pos": blob["pos"], "r": float(blob["r"]) * 1.4, "age": 0.0})
	_blobs = _blobs.filter(func(b): return not b["landed"])
	for splat in _splats:
		splat["age"] += delta
	_splats = _splats.filter(func(s): return float(s["age"]) < 3.0)
	queue_redraw()


func _draw() -> void:
	var resting := _cooldown > 0.0 and _erupt_age < 0.0
	var pressure := float(clicks) / float(CLICKS_TO_ERUPT)
	var shake := Vector2(sin(_time * 80.0), cos(_time * 67.0)) * 2.0 * (_jolt + pressure * 0.4)
	# Cooling lava splats from eruptions.
	for splat in _splats:
		var k := float(splat["age"]) / 3.0
		draw_circle(splat["pos"], float(splat["r"]), LAVA.lerp(CRUST, smoothstep(0.0, 0.6, k)) * Color(1, 1, 1, 1.0 - k * k))
	# Heat glow on the ground (pulses harder as pressure builds).
	var pulse := 0.5 + 0.5 * sin(_time * (3.0 + 6.0 * pressure))
	var glow := 0.08 + 0.06 * pulse + 0.18 * pressure
	if resting:
		glow *= 0.4
	draw_circle(Vector2.ZERO, RADIUS * 2.2, Color(LAVA_DARK, glow))
	# Lava oozing over the lip and creeping a short way down the slope.
	if not resting:
		for drip in _drips:
			var dir := Vector2.RIGHT.rotated(float(drip["angle"]))
			var k := fposmod(_time * float(drip["speed"]) + float(drip["phase"]), 1.0)
			var tip := dir * lerpf(RADIUS * 0.6, RADIUS * 1.9, k)
			var root := dir * RADIUS * 0.55
			draw_line(root, tip, Color(LAVA_DARK, 1.0 - k * 0.6), 4.0 * (1.0 - k * 0.5))
			draw_line(root, tip, Color(LAVA, 1.0 - k), 2.0 * (1.0 - k * 0.5))
			draw_circle(tip, 2.6 * (1.0 - k * 0.5), Color(LAVA, 1.0 - k))
	# Low cone: shadow, dark body, lit top-left facet.
	var cone := _rough_circle(RADIUS, 9, 0.12)
	draw_colored_polygon(Palette.offset_points(cone, Palette.SHADOW_OFFSET * 0.8 + shake), Palette.SHADOW_COLOR)
	draw_colored_polygon(Palette.offset_points(cone, shake), ROCK_DARK)
	draw_colored_polygon(Palette.offset_points(_rough_circle(RADIUS * 0.86, 9, 0.12), Vector2(-1.5, -2.0) + shake), ROCK)
	draw_colored_polygon(Palette.offset_points(_rough_circle(RADIUS * 0.45, 7, 0.1), Vector2(-RADIUS * 0.35, -RADIUS * 0.42) + shake), ROCK_LIGHT)
	# Bubbling pool in the mouth.
	var mouth := RADIUS * 0.5
	draw_circle(shake, mouth, CRUST)
	if resting:
		draw_circle(shake, mouth * 0.7, Color(LAVA_DARK, 0.6))
	else:
		draw_circle(shake, mouth * 0.82, LAVA.lerp(LAVA_HOT, pressure))
		for k in range(3):
			var ph := fposmod(_time * 1.3 + float(k) * 0.37, 1.0)
			var at := shake + Vector2.RIGHT.rotated(_turn + float(k) * 2.1) * mouth * 0.45
			draw_circle(at, mouth * 0.3 * ph, Color(LAVA_CORE, 1.0 - ph))
		# Embers rising.
		for k in range(4):
			var ph := fposmod(_time * 0.6 + float(k) * 0.25, 1.0)
			var at := Vector2(sin(_time * 2.0 + float(k) * 1.7) * 4.0, -ph * RADIUS * 1.8) + Vector2.RIGHT.rotated(float(k) * 1.6) * 3.0
			draw_circle(at, 1.6 * (1.0 - ph), Color(LAVA_HOT, 1.0 - ph))
	# Pressure pips round the rim (one per click).
	if clicks > 0 and not resting:
		for k in range(CLICKS_TO_ERUPT):
			var a := -PI * 0.5 + TAU * float(k) / float(CLICKS_TO_ERUPT)
			var at := Vector2.RIGHT.rotated(a) * (RADIUS + 7.0)
			draw_circle(at, 3.2, Palette.UI_PANEL)
			draw_circle(at, 2.2, LAVA_HOT if k < clicks else Color(ROCK_LIGHT, 0.8))
	if _erupt_age >= 0.0:
		_draw_eruption(_erupt_age / ERUPT_TIME)


## Fountain blobs in flight, a column of fire and the damage shockwave.
func _draw_eruption(t: float) -> void:
	var out := 1.0 - pow(1.0 - minf(t * 1.8, 1.0), 3.0)
	var ring_alpha := 1.0 - smoothstep(0.3, 0.75, t)
	draw_circle(Vector2.ZERO, ERUPT_RADIUS * out, Color(LAVA_DARK, 0.18 * ring_alpha))
	draw_arc(Vector2.ZERO, ERUPT_RADIUS * out, 0.0, TAU, 48, Color(LAVA, 0.9 * ring_alpha), 6.0 * (1.0 - t) + 1.5)
	draw_arc(Vector2.ZERO, ERUPT_RADIUS * out * 0.92, 0.0, TAU, 48, Color(LAVA_HOT, 0.6 * ring_alpha), 2.0)
	if t < 0.5:
		var k := t / 0.5
		var column := RADIUS * (2.2 + 1.5 * sin(PI * k))
		draw_colored_polygon(PackedVector2Array([Vector2(-RADIUS * 0.5, 0.0), Vector2(-RADIUS * 0.25, -column), Vector2(RADIUS * 0.25, -column), Vector2(RADIUS * 0.5, 0.0)]), Color(LAVA, 1.0 - k))
		draw_circle(Vector2(0.0, -column), RADIUS * 0.45 * (1.0 - k * 0.5), Color(LAVA_HOT, 1.0 - k))
		draw_circle(Vector2.ZERO, RADIUS * 0.8, Color(LAVA_CORE, 1.0 - k))
	for blob in _blobs:
		var p: Vector2 = blob["pos"]
		var z: float = blob["z"]
		draw_circle(p + Vector2(2.0, 3.0), float(blob["r"]), Color(0, 0, 0, 0.25))
		draw_circle(p + Vector2(0.0, -z), float(blob["r"]), LAVA)
		draw_circle(p + Vector2(-0.8, -z - 0.8), float(blob["r"]) * 0.5, LAVA_HOT)


func _rough_circle(radius: float, sides: int, jag: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in range(sides):
		var a := _turn + TAU * float(k) / float(sides)
		points.append(Vector2.RIGHT.rotated(a) * radius * (1.0 - jag * float((k * 7) % 3) / 2.0))
	return points
