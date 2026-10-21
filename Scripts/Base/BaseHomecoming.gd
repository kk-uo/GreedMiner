extends Node2D

## What the base crew does when the ship comes home (presentation only):
## - &"haul": dwarves stream out of the warehouse, pick up glowing ore chunks
##   at the landed ship and carry them into the warehouse (more ore, more
##   dwarves), with a gold sparkle at every delivery; then go back inside.
## - &"wrecked": the ship was destroyed - it comes home pouring black smoke;
##   mechanics with wrenches hurry out of the tunnel and repair it all round,
##   the smoke thinning out and the scorched hull brightening as they work;
##   then they leave.
## BattleMain sets `pending` right before returning; BaseMain calls
## `consume(base)` on arrival. Load with preload(); no class_name on purpose.

static var pending: Dictionary = {}

const SMOKE := Color("2B2622")
const SMOKE_LIGHT := Color("4A423C")
const EMBER := Color("FF8A3D")
## Seconds after arrival before the crew comes out (the landing plays first).
const CREW_DELAY: float = 1.7
const REPAIR_TIME: float = 12.0
const TRIPS_PER_DWARF: int = 2

var kind: StringName = &"haul"
var ore: float = 0.0
var hangar: AsteroidHangar
var ship: Node2D

var _time: float = 0.0
var _crew: Array = []
var _spawned: bool = false
var _repair: float = 0.0
var _puffs: Array = []
var _sparkles: Array = []
var _smoke_spots: Array = []
var _rng := RandomNumberGenerator.new()


## Starts the homecoming scene queued by the battle (if any) and clears it.
static func consume(base: Node) -> Node:
	if pending.is_empty():
		return null
	var info := pending
	pending = {}
	var what: StringName = info.get("kind", &"")
	if what == &"haul" and float(info.get("ore", 0.0)) <= 0.0:
		return null
	if what != &"haul" and what != &"wrecked":
		return null
	var node: Node2D = load("res://Scripts/Base/BaseHomecoming.gd").new()
	node.name = "Homecoming"
	node.set("kind", what)
	node.set("ore", float(info.get("ore", 0.0)))
	node.set("hangar", base.get("hangar"))
	node.set("ship", base.get("ship"))
	base.add_child(node)
	return node


func _ready() -> void:
	_rng.randomize()
	z_index = 30
	if kind == &"wrecked":
		for mock in [Vector2(600, 320), Vector2(684, 352), Vector2(626, 404), Vector2(662, 300)]:
			_smoke_spots.append(_world(mock))


func _world(mock: Vector2) -> Vector2:
	return hangar.to_global(AsteroidHangar.mock_to_local(mock))


func _local(mock: Vector2) -> Vector2:
	return AsteroidHangar.mock_to_local(mock)


func _process(delta: float) -> void:
	_time += delta
	if not _spawned and _time >= CREW_DELAY:
		_spawned = true
		if kind == &"haul":
			_spawn_haulers()
		else:
			_spawn_mechanics()
	if kind == &"wrecked":
		_process_wreck(delta)
	else:
		_process_haul()
	_unstick(delta)
	_update_puffs(delta)
	_update_sparkles(delta)
	queue_redraw()
	if _spawned and _crew.is_empty() and _puffs.is_empty() and _sparkles.is_empty():
		_restore_ship()
		queue_free()


# ==========================================
# Haul: ore into the warehouse
# ==========================================

func _spawn_haulers() -> void:
	var count := clampi(2 + int(ore / 150.0), 3, 6)
	var pickups := [Vector2(606, 456), Vector2(674, 456), Vector2(736, 412), Vector2(736, 344), Vector2(640, 462), Vector2(736, 380)]
	var drops := [Vector2(962, 527), Vector2(948, 552), Vector2(975, 505)]
	var tunics := [Color("7A5A3A"), Color("6B4F7A"), Color("A07A3E"), Color("5A6E7E"), Color("8A3B2E"), Color("4F6B4A")]
	for index in range(count):
		var dwarf := BaseDwarf.new()
		dwarf.mode = &"job"
		dwarf.cargo = &"ore"
		dwarf.tunic = tunics[index % tunics.size()]
		dwarf.body_scale = AsteroidHangar.LAYOUT_SCALE * 1.25
		dwarf.walk_speed = _rng.randf_range(75.0, 92.0)
		dwarf.obstacles = hangar.call("_crew_obstacles")
		var drop: Vector2 = _local(drops[index % drops.size()])
		dwarf.steps = [
			{"to": _local(pickups[index % pickups.size()]), "wait": 0.9, "face": _local(AsteroidHangar.PAD_RECT.get_center()), "carry": true},
			{"to": drop, "wait": 0.6, "face": _local(AsteroidHangar.VAULT_PILE), "carry": false},
		]
		# Out of the warehouse door, a little apart in time.
		dwarf.route = PackedVector2Array([_local(Vector2(978, 512)) + Vector2(_rng.randf_range(-8, 8), _rng.randf_range(-8, 8))])
		dwarf.visible = false
		hangar.add_child(dwarf)
		_crew.append({"dwarf": dwarf, "start": _time + 0.55 * float(index), "trips": 0, "was": false, "leaving": false})


func _process_haul() -> void:
	for entry in _crew.duplicate():
		var dwarf: BaseDwarf = entry["dwarf"]
		if not is_instance_valid(dwarf):
			_crew.erase(entry)
			continue
		if not dwarf.visible:
			dwarf.set_process(_time >= float(entry["start"]))
			dwarf.visible = _time >= float(entry["start"])
			continue
		# Delivery: carrying flips back off at the warehouse.
		if bool(entry["was"]) and not dwarf.carrying:
			entry["trips"] = int(entry["trips"]) + 1
			_burst(hangar.to_global(dwarf.position + Vector2.RIGHT.rotated(dwarf.facing) * 12.0))
			if int(entry["trips"]) >= TRIPS_PER_DWARF:
				_send_home(entry, _local(Vector2(980, 512)))
		entry["was"] = dwarf.carrying
		_check_gone(entry)


# ==========================================
# Wrecked: smoke and repairs
# ==========================================

func _spawn_mechanics() -> void:
	var spots := [
		[Vector2(546, 322), Vector2(546, 398)],
		[Vector2(604, 456), Vector2(676, 456)],
		[Vector2(736, 404), Vector2(736, 332)],
		[Vector2(676, 266), Vector2(604, 266)],
	]
	var tunics := [Color("4F6B4A"), Color("5A6E7E"), Color("7A5A3A"), Color("8A6A2E")]
	var pad := _local(AsteroidHangar.PAD_RECT.get_center())
	for index in range(spots.size()):
		var dwarf := BaseDwarf.new()
		dwarf.mode = &"job"
		dwarf.tool = &"wrench"
		dwarf.tunic = tunics[index]
		dwarf.body_scale = AsteroidHangar.LAYOUT_SCALE * 1.25
		dwarf.walk_speed = _rng.randf_range(95.0, 110.0)
		dwarf.obstacles = hangar.call("_crew_obstacles")
		var steps := []
		for mock in spots[index]:
			steps.append({"to": _local(mock), "wait": 2.6, "face": pad, "work": true})
		dwarf.steps = steps
		# Out of the tunnel mouth (clear of the crate pile beside it).
		dwarf.route = PackedVector2Array([_local(Vector2(640, 655)) + Vector2(_rng.randf_range(-14, 14), 0)])
		dwarf.visible = false
		hangar.add_child(dwarf)
		_crew.append({"dwarf": dwarf, "start": _time + 0.4 * float(index), "leaving": false})


func _process_wreck(delta: float) -> void:
	var working := 0
	for entry in _crew.duplicate():
		var dwarf: BaseDwarf = entry["dwarf"]
		if not is_instance_valid(dwarf):
			_crew.erase(entry)
			continue
		if not dwarf.visible:
			dwarf.set_process(_time >= float(entry["start"]))
			dwarf.visible = _time >= float(entry["start"])
			continue
		if not bool(entry["leaving"]) and bool(dwarf.get("_working")):
			working += 1
		if _repair >= 1.0 and not bool(entry["leaving"]):
			_send_home(entry, _local(Vector2(640, 655)))
		_check_gone(entry)
	if _spawned:
		_repair = minf(_repair + delta * (0.6 + 0.4 * float(working) / 4.0) / REPAIR_TIME, 1.0)
	# Scorched hull brightening as it is fixed.
	if is_instance_valid(ship):
		var dark := 1.0 - _repair
		var tint := Color(1.0, 1.0, 1.0).lerp(Color(0.55, 0.5, 0.47), dark)
		ship.modulate = Color(tint, ship.modulate.a)
	# Smoke: thick at first, thinning out with the repairs.
	var intensity := 1.0 - smoothstep(0.0, 0.95, _repair)
	if intensity > 0.02:
		for spot in _smoke_spots:
			if _rng.randf() < delta * 7.0 * intensity:
				var at: Vector2 = spot + Vector2(_rng.randf_range(-10, 10), _rng.randf_range(-8, 8)) * AsteroidHangar.LAYOUT_SCALE
				_puffs.append({"at": at, "age": 0.0, "life": _rng.randf_range(2.2, 3.4), "r": _rng.randf_range(9.0, 15.0) * AsteroidHangar.LAYOUT_SCALE * (0.6 + 0.4 * intensity), "drift": _rng.randf_range(10.0, 26.0), "dark": _rng.randf() < 0.6})


func _restore_ship() -> void:
	if kind == &"wrecked" and is_instance_valid(ship):
		ship.modulate = Color(1, 1, 1, ship.modulate.a)


# ==========================================
# Shared
# ==========================================

func _send_home(entry: Dictionary, door: Vector2) -> void:
	var dwarf: BaseDwarf = entry["dwarf"]
	entry["leaving"] = true
	entry["door"] = door
	dwarf.carrying = false
	dwarf.steps = [{"to": door, "wait": 99.0}]
	dwarf.set("_step_index", 0)
	dwarf.set("_pause_left", 0.0)


func _check_gone(entry: Dictionary) -> void:
	if not bool(entry["leaving"]):
		return
	var dwarf: BaseDwarf = entry["dwarf"]
	if dwarf.position.distance_to(entry["door"]) < 6.0:
		dwarf.modulate.a -= get_process_delta_time() * 2.5
		if dwarf.modulate.a <= 0.0:
			dwarf.queue_free()
			_crew.erase(entry)


func _burst(at: Vector2) -> void:
	for k in range(7):
		var a := TAU * float(k) / 7.0 + _rng.randf() * 0.4
		_sparkles.append({"at": at, "dir": Vector2.RIGHT.rotated(a), "age": 0.0, "speed": _rng.randf_range(30.0, 55.0)})
	_sparkles.append({"at": at, "dir": Vector2.ZERO, "age": 0.0, "speed": 0.0, "plus": true})


func _update_puffs(delta: float) -> void:
	for puff in _puffs.duplicate():
		puff["age"] = float(puff["age"]) + delta
		if float(puff["age"]) >= float(puff["life"]):
			_puffs.erase(puff)


func _update_sparkles(delta: float) -> void:
	for spark in _sparkles.duplicate():
		spark["age"] = float(spark["age"]) + delta
		if float(spark["age"]) >= (1.1 if spark.has("plus") else 0.6):
			_sparkles.erase(spark)


func _draw() -> void:
	var s := AsteroidHangar.LAYOUT_SCALE
	# Embers glowing at the smoke sources while the damage is bad.
	if kind == &"wrecked":
		var heat := 1.0 - smoothstep(0.0, 0.6, _repair)
		for spot in _smoke_spots:
			var flick := 0.6 + 0.4 * sin(_time * 13.0 + spot.x)
			draw_circle(to_local(spot), 7.0 * s * heat, Color(EMBER, 0.35 * heat * flick))
			draw_circle(to_local(spot), 3.0 * s * heat, Color("FFD27A", 0.8 * heat * flick))
	for puff in _puffs:
		var k := float(puff["age"]) / float(puff["life"])
		var at: Vector2 = to_local(puff["at"]) + Vector2(float(puff["drift"]) * k, -58.0 * s * k)
		var r := float(puff["r"]) * lerpf(0.6, 2.1, k)
		var alpha := (1.0 - k) * smoothstep(0.0, 0.12, k) * 0.75
		draw_circle(at + Vector2(2, 3) * s, r, Color(0, 0, 0, alpha * 0.25))
		draw_circle(at, r, Color(SMOKE if bool(puff["dark"]) else SMOKE_LIGHT, alpha))
		draw_circle(at + Vector2(-0.3, -0.3) * r, r * 0.55, Color(SMOKE_LIGHT, alpha * 0.6))
	for spark in _sparkles:
		var age := float(spark["age"])
		var at: Vector2 = to_local(spark["at"])
		if spark.has("plus"):
			var k := age / 1.1
			var font := ThemeDB.fallback_font
			draw_string(font, at + Vector2(-8, -14.0 - 22.0 * k), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Palette.GOLD, 1.0 - k))
			continue
		var k := age / 0.6
		var p: Vector2 = at + (spark["dir"] as Vector2) * float(spark["speed"]) * k * s
		var r := 2.6 * (1.0 - k) * s
		if r < 0.4:
			continue
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)]), Color(Palette.GOLD, 1.0 - k))


## Watchdog: a walking crew member that has hardly moved over the last 0.8 s
## (wedged against an obstacle) is nudged straight toward where it is going.
func _unstick(delta: float) -> void:
	for entry in _crew:
		var dwarf: BaseDwarf = entry["dwarf"]
		if not is_instance_valid(dwarf) or not dwarf.visible:
			continue
		var steps: Array = dwarf.steps
		if steps.is_empty() or float(dwarf.get("_pause_left")) > 0.0:
			entry["window"] = 0.0
			entry["last"] = dwarf.position
			continue
		var target: Vector2 = steps[int(dwarf.get("_step_index")) % steps.size()]["to"]
		entry["window"] = float(entry.get("window", 0.0)) + delta
		if float(entry["window"]) < 0.8:
			continue
		var last: Vector2 = entry.get("last", dwarf.position)
		if dwarf.position.distance_to(last) < 10.0 and dwarf.position.distance_to(target) > 4.0:
			dwarf.position = dwarf.position.move_toward(target, 24.0 * AsteroidHangar.LAYOUT_SCALE)
		entry["window"] = 0.0
		entry["last"] = dwarf.position
