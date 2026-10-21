class_name EnergyModule
extends ShipModule

## Basic ship energy module.
##
## Power and expansion capacities are deliberately independent so later
## upgrades can change one value without implicitly changing the other.

## Ship power supplied by this module before research (Energy Core adds more).
@export var power_capacity: int = 4

## Reserved for future laboratory research and ship-grid expansion.
@export var expansion_capacity: int = 0

## Energy modules produce power and therefore consume none in v0.1.
@export var power_consumption: int = 0


func get_module_category() -> StringName:
	return CATEGORY_ENERGY


func get_power_consumption() -> int:
	return maxi(power_consumption, 0)


## Base power plus the Laboratory's Energy Core research bonus.
func get_power_capacity() -> int:
	return maxi(power_capacity + ResearchManager.get_energy_module_power_bonus(), 0)


## Base expansion plus research (Expandable Cells). Only an interface for
## the future hull slot expansion; it adds no slot by itself.
func get_expansion_capacity() -> int:
	return maxi(expansion_capacity + ResearchManager.get_energy_module_expansion_bonus(), 0)


## Shielded Cells research: every installed battery reinforces the hull.
func get_max_hp_bonus() -> float:
	return maxf(ResearchManager.get_energy_module_hp_bonus(), 0.0)


# ==========================================
# Presentation: Tesla coil with a floating diamond energy crystal
# ==========================================

const Y_DARK := Color("B87A0A")
const Y_BASE := Color("FFC21A")
const Y_MID := Color("FFD84A")
const Y_LIGHT := Color("FFF3A6")
const Y_WHITE := Color("FFFBE8")
const Y_FACET_DARK := Color("E09A0C")
const COPPER := Color("C98A2B")
const COPPER_DARK := Color("8F5F1D")

## Seconds per bead / float loop (supply lines, crystal bob).
const LOOP_TIME: float = 1.6
## One heartbeat = a strong "lub" then a soft "dub": [seconds after the
## heartbeat starts, strength].
const BEATS: Array = [[0.0, 1.0], [0.22, 0.6]]
## Seconds a beat's swell lasts / a shock ring takes to fade out.
const BEAT_PULSE_TIME: float = 0.19
const RING_TIME: float = 0.55

## Seconds between heartbeats (lub-dub). Higher = calmer.
@export_range(0.8, 10.0, 0.1) var heartbeat_interval: float = 3.2
## Seconds between the occasional lightning zaps along a supply line.
const ZAP_INTERVAL_MIN: float = 1.4
const ZAP_INTERVAL_MAX: float = 3.2
## How long one zap stays visible.
const ZAP_TIME: float = 0.16
const TERMINALS: Array[Vector2] = [Vector2(-15, -15), Vector2(15, -15), Vector2(15, 15), Vector2(-15, 15)]

var _anim_time: float = 0.0
var _arc_rng := RandomNumberGenerator.new()
var _next_zap: float = 0.0
var _zap_start: float = -10.0
var _zap_line: int = 0
var _zap_seed: int = 0


func _ready() -> void:
	# Desync modules so several energy cells don't pulse in lockstep.
	_anim_time = fmod(float(get_instance_id() % 997) * 0.173, 10.0)
	_arc_rng.seed = get_instance_id()
	_next_zap = _anim_time + _arc_rng.randf_range(0.4, ZAP_INTERVAL_MAX)


func _process(delta: float) -> void:
	_anim_time += delta
	if _anim_time >= _next_zap:
		_zap_start = _anim_time
		_zap_line = _arc_rng.randi_range(0, TERMINALS.size() - 1)
		_zap_seed = _arc_rng.randi()
		_next_zap = _anim_time + _arc_rng.randf_range(ZAP_INTERVAL_MIN, ZAP_INTERVAL_MAX)
	queue_redraw()


## Seconds since the current heartbeat started.
func _heart_time() -> float:
	return fposmod(_anim_time, maxf(heartbeat_interval, 0.5))


## 0..1 heartbeat swell at heart time h (seconds).
static func beat_amount(h: float) -> float:
	var amount: float = 0.0
	for beat in BEATS:
		var age: float = h - float(beat[0])
		if age >= 0.0 and age < BEAT_PULSE_TIME:
			amount = maxf(amount, float(beat[1]) * (1.0 - age / BEAT_PULSE_TIME))
	return amount


## Style A: bone mounting plate, a copper Tesla coil with four corner
## terminals and a floating yellow diamond crystal. The crystal beats like a
## heart ("lub-dub", every heartbeat_interval seconds), each beat sends a shock ring out past the cell. Calm
## supply lines carry energy beads from the crystal to the four terminals; now
## and then a thin lightning zap runs along one of them. Energy pulses keep
## flowing out of all four sides to the neighbours.
func _draw() -> void:
	var t: float = fposmod(_anim_time / LOOP_TIME, 1.0)
	var beat: float = beat_amount(_heart_time())
	var shadow := Palette.local_shadow_offset(self)

	var plate := Rect2(-22.0, -22.0, 44.0, 44.0)
	Palette.draw_rounded_rect(self, Rect2(plate.position + shadow * 0.6, plate.size), 6.0, Palette.SHADOW_COLOR)
	Palette.draw_rounded_rect(self, plate, 6.0, Palette.SHIP_PART_EDGE)
	Palette.draw_rounded_rect(self, Rect2(-22.0, -22.0, 42.0, 41.0), 6.0, Palette.SHIP_PART)

	for terminal in TERMINALS:
		Palette.draw_rounded_rect(self, Rect2(terminal - Vector2(4.0, 4.0), Vector2(8.0, 8.0)), 2.0, Palette.MECH)
		draw_circle(terminal, 2.2, Y_DARK)

	# Coil base.
	draw_circle(shadow * 0.25, 13.0, Color(0.0, 0.0, 0.0, 0.25))
	draw_circle(Vector2.ZERO, 13.0, Palette.MECH)
	draw_circle(Vector2(-1.0, -1.0), 11.5, Palette.MECH_LIGHT)
	draw_arc(Vector2.ZERO, 10.5, 0.0, TAU, 28, COPPER, 1.6)
	draw_arc(Vector2.ZERO, 8.5, 0.0, TAU, 24, COPPER_DARK, 1.6)
	draw_circle(Vector2.ZERO, 9.0 + 6.0 * beat, Color(Y_BASE, 0.18 + 0.35 * beat))

	_draw_shock_rings(_heart_time())
	_draw_supply(t)

	var bob: float = 1.0 + 0.8 * sin(t * TAU)
	var size: float = 1.0 + 0.2 * beat
	_draw_supply_lines(t, beat, bob, size)
	_draw_crystal(size, bob, shadow)


func _draw_shock_rings(h: float) -> void:
	for beat in BEATS:
		var strength: float = beat[1]
		var age: float = (h - float(beat[0])) / RING_TIME
		if age < 0.0 or age >= 1.0:
			continue
		var eased: float = age * age * (3.0 - 2.0 * age)
		var radius: float = 9.0 + 26.0 * eased * (0.75 + 0.25 * strength)
		var fade: float = 1.0 - age
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(Y_BASE, 0.25 * fade), 5.0 * strength * fade + 0.5)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(Y_LIGHT, 0.9 * strength * fade), 2.4 * strength * fade + 0.3)


## Arrow pulses leaving the plate on all four sides (toward the neighbours).
func _draw_supply(t: float) -> void:
	for side in range(4):
		var dir: Vector2 = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP][side]
		var perp := Vector2(-dir.y, dir.x)
		for index in range(2):
			var k: float = fposmod(t * 2.0 + float(index) * 0.5 + float(side) * 0.13, 1.0)
			var at: Vector2 = dir * lerpf(22.0, 32.0, k)
			var alpha: float = sin(PI * k)
			draw_circle(at, 3.6, Color(Y_BASE, 0.45 * alpha))
			var arrow := PackedVector2Array([at + dir * 2.8, at - perp * 2.0, at + perp * 2.0])
			draw_colored_polygon(arrow, Color(Y_BASE, alpha))
			draw_polyline(PackedVector2Array([arrow[0], arrow[1], arrow[2], arrow[0]]), Color(Y_DARK, alpha), 0.8)


## Steady lines from the crystal to each terminal with beads flowing along
## them; a thin zap occasionally crackles along one line.
func _draw_supply_lines(t: float, beat: float, bob: float, size: float) -> void:
	var zap_age: float = (_anim_time - _zap_start) / ZAP_TIME
	for index in range(TERMINALS.size()):
		var terminal: Vector2 = TERMINALS[index]
		var from := Vector2(3.3 * signf(terminal.x), -bob + 4.7 * signf(terminal.y)) * size
		var lit: float = 0.55 + 0.45 * beat
		draw_line(from, terminal, Color(Y_BASE, 0.18 + 0.2 * beat), 3.6)
		draw_line(from, terminal, Y_DARK, 1.8)
		draw_line(from, terminal, Color(Y_MID, lit), 0.9)
		for bead in range(2):
			var k: float = fposmod(t * 2.0 + float(bead) * 0.5 + float(index) * 0.25, 1.0)
			var at: Vector2 = from.lerp(terminal, k)
			draw_circle(at, 2.0, Color(Y_BASE, 0.35))
			draw_circle(at, 1.0, Y_LIGHT)
		draw_circle(terminal, 2.2, Y_DARK.lerp(Y_BASE, beat))
		if index == _zap_line and zap_age >= 0.0 and zap_age < 1.0:
			_draw_zap(from, terminal, 1.0 - zap_age)


## One thin lightning crackle along a supply line, fixed shape for the zap.
func _draw_zap(from: Vector2, to: Vector2, alpha: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _zap_seed
	var points := PackedVector2Array([from])
	var along: Vector2 = to - from
	var normal: Vector2 = along.orthogonal().normalized()
	var segments: int = 5
	for index in range(1, segments):
		var k: float = float(index) / float(segments)
		points.append(from + along * k + normal * rng.randf_range(-2.4, 2.4) * sin(PI * k))
	points.append(to)
	draw_polyline(points, Color(Y_BASE, 0.3 * alpha), 2.6)
	draw_polyline(points, Color(Y_WHITE, alpha), 1.0)
	draw_circle(to, 3.0, Color(Y_BASE, 0.45 * alpha))
	draw_circle(to, 1.6, Color(Y_WHITE, alpha))


## Floating faceted diamond: tall rhombus, four shaded facets + a glint.
func _draw_crystal(size: float, bob: float, shadow: Vector2) -> void:
	var half_w: float = 6.6 * size
	var half_h: float = 9.4 * size
	var center := Vector2(0.0, -bob)
	var top := center + Vector2(0.0, -half_h)
	var right := center + Vector2(half_w, 0.0)
	var bottom := center + Vector2(0.0, half_h)
	var left := center + Vector2(-half_w, 0.0)
	var drop: Vector2 = shadow * 0.5 + Vector2(0.0, bob)
	draw_colored_polygon(PackedVector2Array([top + drop, right + drop, bottom + drop, left + drop]), Color(0.0, 0.0, 0.0, 0.22))
	draw_colored_polygon(PackedVector2Array([top + Vector2(0, -1.2), right + Vector2(1.2, 0), bottom + Vector2(0, 1.2), left + Vector2(-1.2, 0)]), Y_DARK)
	draw_colored_polygon(PackedVector2Array([top, center, left]), Y_LIGHT)
	draw_colored_polygon(PackedVector2Array([top, right, center]), Y_BASE)
	draw_colored_polygon(PackedVector2Array([center, right, bottom]), Y_FACET_DARK)
	draw_colored_polygon(PackedVector2Array([left, center, bottom]), Y_MID)
	draw_colored_polygon(PackedVector2Array([top + Vector2(-1.2, 3.2), top + Vector2(0.4, 1.6), center + Vector2(-2.6 * size, -1.2)]), Color(Y_WHITE, 0.9))
