extends Node2D

## Siege Cannon strike, art direction C "golden rune meteor":
## 1. mark  - a dwarven rune circle (two counter-rotating rings) blooms on
##            the target, its gold fill rising as the shot approaches;
## 2. fall  - a golden meteor streaks in from the cannon's side of the sky
##            with a long fire trail, its shadow growing on the mark;
## 3. impact - a pillar of light, white flash, gold fireball, rune and dust
##            shockwaves, flying sparks, smoke, a small camera kick, and a
##            glowing crater left behind for a moment.
## Damage still resolves through FusionProjectile at the landing moment, so
## attribution, artifacts and boss hits are unchanged. Presentation only.

const GOLD := Color("F2C14A")
const GOLD_LIGHT := Color("FFF1B0")
const GOLD_DEEP := Color("B07A1A")
const FIRE := Color("FF9A2E")
const IMPACT_TIME: float = 1.3
const CRATER_TIME: float = 2.4

var source_weapon: WeaponModule
var projectile_scene: PackedScene
var damage: float = 0.0
var blast_radius: float = 40.0
var shell_radius: float = 6.0
var mark_duration: float = 0.6
var fall_duration: float = 0.4
var _elapsed: float = 0.0
var _landed: bool = false
var _since_impact: float = 0.0
var _from: Vector2 = Vector2(-0.65, -0.76)
var _sparks: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"siege_airstrikes")
	z_index = 8
	_rng.seed = get_instance_id()
	if is_instance_valid(source_weapon):
		var away := source_weapon.global_position - global_position
		if away.length_squared() > 1.0:
			# Comes in from the cannon's side, high in the sky.
			_from = (away.normalized() + Vector2(0.0, -1.2)).normalized()
	queue_redraw()


func _process(delta: float) -> void:
	if not _landed:
		_elapsed += delta
		if _elapsed >= mark_duration + fall_duration:
			_land()
	else:
		_since_impact += delta
		if _since_impact >= CRATER_TIME:
			queue_free()
			return
	queue_redraw()


func _land() -> void:
	if _landed:
		return
	_landed = true
	_since_impact = 0.0
	# The group lists pending strikes only; the explosion art lingers on.
	remove_from_group(&"siege_airstrikes")
	if projectile_scene != null:
		var shell := projectile_scene.instantiate() as FusionProjectile
		if shell != null:
			shell.damage = damage
			shell.aoe_radius = blast_radius
			shell.projectile_range = shell_radius
			shell.visual_kind = FusionWeapon.VisualKind.CANNON
			shell.source_weapon = source_weapon if is_instance_valid(source_weapon) else null
			get_parent().add_child(shell)
			shell.global_position = global_position
			shell._finish_impact(null)
	for i in range(22):
		var a := _rng.randf() * TAU
		_sparks.append({"dir": Vector2.from_angle(a), "speed": _rng.randf_range(0.6, 1.0), "lift": _rng.randf_range(10.0, 34.0), "size": _rng.randf_range(2.0, 3.6)})
	_kick_camera(6.0, 0.3)


func _kick_camera(amount: float, duration: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var tween := camera.create_tween()
	var steps: int = maxi(int(duration / 0.03), 2)
	for step in range(steps):
		var strength := amount * (1.0 - float(step) / float(steps))
		tween.tween_property(camera, "offset", Vector2(randf_range(-strength, strength), randf_range(-strength, strength)), 0.03)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.03)


func _draw() -> void:
	# Everything is sized to the real blast radius: the mark's outer rune ring,
	# the fireball and the shockwaves all end exactly at the damage edge.
	var R := maxf(blast_radius, 12.0)
	if not _landed:
		_draw_mark(R)
		if _elapsed >= mark_duration:
			_draw_meteor(R, clampf((_elapsed - mark_duration) / maxf(fall_duration, 0.01), 0.0, 1.0))
	else:
		_draw_impact(R, _since_impact)


func _draw_mark(R: float) -> void:
	var total := maxf(mark_duration + fall_duration, 0.01)
	var k := clampf(_elapsed / total, 0.0, 1.0)
	var bloom := clampf(_elapsed / 0.18, 0.0, 1.0)
	draw_circle(Vector2.ZERO, R * 1.05, Color(GOLD, (0.06 + 0.16 * k) * bloom))
	if _elapsed >= mark_duration:
		var f := clampf((_elapsed - mark_duration) / maxf(fall_duration, 0.01), 0.0, 1.0)
		draw_circle(Vector2.ZERO, R * (0.25 + 0.6 * f), Color(0, 0, 0, 0.18 + 0.25 * f))
	_rune_ring(R * lerpf(1.35, 1.0, clampf(_elapsed / maxf(mark_duration, 0.01), 0.0, 1.0)) * bloom, _elapsed * 1.6, GOLD, bloom, 18)
	_rune_ring(R * 0.55 * bloom, -_elapsed * 2.4, GOLD_LIGHT, bloom * 0.9, 10)
	_star(Vector2.ZERO, 9.0, 3.5, 4, _elapsed * 2.0, Color(GOLD_LIGHT, bloom))


func _draw_meteor(R: float, f: float) -> void:
	var e := f * f * f
	var start := _from * 300.0
	var at := start.lerp(Vector2.ZERO, e)
	var back := _from.normalized()
	for j in range(9):
		var q := float(j) / 9.0
		var p := at + back * (14.0 + 150.0 * q) * (1.15 - 0.4 * f)
		draw_circle(p, (13.0 - 10.0 * q) * (1.3 - 0.4 * f), Color(FIRE if j % 2 == 1 else GOLD, 0.8 * (1.0 - q)))
	draw_circle(at, 22.0, Color(GOLD, 0.35))
	draw_circle(at, 13.0, GOLD_LIGHT)
	draw_circle(at - Vector2(3, 3), 5.0, Color.WHITE)


func _draw_impact(R: float, a: float) -> void:
	# glowing crater, fading at the end
	var crater_alpha := clampf(a / 0.2, 0.0, 1.0) * (1.0 - clampf((a - IMPACT_TIME) / (CRATER_TIME - IMPACT_TIME), 0.0, 1.0))
	if crater_alpha > 0.0:
		draw_circle(Vector2.ZERO, R * 0.95, Color(0.12, 0.09, 0.07, 0.55 * crater_alpha))
		draw_circle(Vector2.ZERO, R * 0.65, Color(0.07, 0.05, 0.04, 0.6 * crater_alpha))
		for i in range(8):
			var p := Vector2.from_angle(float(i) * 2.4) * R * (0.25 + 0.08 * float(i))
			draw_circle(p, 2.2, Color(GOLD, crater_alpha * (0.5 + 0.5 * sin(a * 9.0 + float(i)))))
	# pillar of light straight up from the hit
	var pk := clampf(a / 0.35, 0.0, 1.0)
	if pk < 1.0:
		var w := R * 0.8 * (1.0 - pk)
		draw_rect(Rect2(Vector2(-w * 0.5, -620.0), Vector2(w, 620.0)), Color(GOLD_LIGHT, 0.75 * (1.0 - pk)))
		draw_rect(Rect2(Vector2(-w * 0.18, -620.0), Vector2(w * 0.36, 620.0)), Color(1, 1, 1, 0.8 * (1.0 - pk)))
	if a < 0.12:
		draw_circle(Vector2.ZERO, R * (0.5 + a * 4.0), Color(1, 1, 1, 0.9 * (1.0 - a / 0.12)))
	# shockwaves: rune ring and dust ring
	var sk := clampf(a / 0.6, 0.0, 1.0)
	if sk < 1.0:
		var grow := 1.0 - pow(1.0 - sk, 3.0)
		_rune_ring(R * (0.45 + 0.55 * grow), a * 3.0, GOLD, 1.0 - sk, 18)
		draw_arc(Vector2.ZERO, R * (0.3 + 0.7 * grow), 0.0, TAU, 64, Color(GOLD_LIGHT, 0.85 * (1.0 - sk)), 8.0 * (1.0 - sk) + 1.0)
		draw_arc(Vector2.ZERO, R * (0.2 + 0.7 * grow), 0.0, TAU, 64, Color(0.72, 0.64, 0.55, 0.45 * (1.0 - sk)), 12.0 * (1.0 - sk) + 1.0)
	# gold fireball
	var fk := clampf(a / 0.9, 0.0, 1.0)
	if fk < 1.0:
		var grow := 1.0 - pow(1.0 - clampf(fk / 0.35, 0.0, 1.0), 3.0)
		var fade := 1.0 - clampf((fk - 0.35) / 0.65, 0.0, 1.0)
		var layers := [[Color("7A4E10"), 1.0], [Color("D98A1E"), 0.8], [GOLD, 0.58], [GOLD_LIGHT, 0.34]]
		for layer in range(layers.size()):
			var col: Color = layers[layer][0]
			var scale_value: float = layers[layer][1]
			for i in range(6):
				var ang := float(i) * 1.05 + float(layer) * 0.4
				var d := R * 0.3 * grow * (0.4 + 0.6 * fmod(float(i) * 0.37, 1.0))
				var rr := R * scale_value * (0.5 + 0.2 * fmod(float(i) * 0.53, 1.0)) * grow
				draw_circle(Vector2.from_angle(ang) * d + Vector2(-layer * 2.0, -layer * 3.0 - 18.0 * clampf((fk - 0.3) / 0.7, 0.0, 1.0)), rr, Color(col, fade * (0.95 if layer > 0 else 0.8)))
	# sparks thrown out in an arc
	var spk := clampf(a / 0.8, 0.0, 1.0)
	if spk < 1.0:
		var grow := 1.0 - pow(1.0 - spk, 3.0)
		for spark in _sparks:
			var p: Vector2 = (spark["dir"] as Vector2) * R * grow * float(spark["speed"])
			p.y -= sin(spk * PI) * float(spark["lift"])
			draw_circle(p, float(spark["size"]), Color(GOLD_LIGHT, 1.0 - spk))
	# smoke rising after the fire
	var smk := clampf((a - 0.25) / 1.1, 0.0, 1.0)
	if smk > 0.0 and smk < 1.0:
		for i in range(9):
			var ang := float(i) * 0.7
			var d := R * (0.2 + 0.6 * smk) * (0.5 + 0.5 * fmod(float(i) * 0.41, 1.0))
			var p := Vector2(cos(ang) * d, sin(ang) * d * 0.7 - 50.0 * smk)
			draw_circle(p, R * (0.2 + 0.3 * smk), Color(0.43, 0.38, 0.35, 0.5 * (1.0 - smk)))


func _rune_ring(radius: float, rot: float, color: Color, alpha: float, ticks: int) -> void:
	if alpha <= 0.0 or radius <= 0.0:
		return
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(color, alpha), 3.0)
	draw_arc(Vector2.ZERO, radius * 0.82, 0.0, TAU, 64, Color(color, alpha * 0.8), 1.5)
	for i in range(ticks):
		var a := rot + TAU * float(i) / float(ticks)
		var p := Vector2.from_angle(a) * radius * 0.91
		if i % 3 == 0:
			var t := Vector2.from_angle(a + PI * 0.5) * 4.0
			var n := Vector2.from_angle(a) * 5.0
			draw_colored_polygon(PackedVector2Array([p - n, p + t, p + n, p - t]), Color(color, alpha))
		else:
			var t := Vector2.from_angle(a + PI * 0.5) * 3.0
			draw_line(p - t, p + t, Color(color, alpha), 2.0)


func _star(c: Vector2, r1: float, r2: float, n: int, rot: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(n * 2):
		points.append(c + Vector2.from_angle(rot + PI * float(i) / float(n)) * (r1 if i % 2 == 0 else r2))
	draw_colored_polygon(points, color)


## Launch flash at the cannon: starburst, an expanding rune ring, a golden
## bolt shooting up into the sky, and smoke. Spawned by SiegeCannon.
class LaunchFx extends Node2D:
	var _age: float = 0.0

	func _ready() -> void:
		z_index = 9

	func _process(delta: float) -> void:
		_age += delta
		if _age > 1.0:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var gold := Color("F2C14A")
		var light := Color("FFF1B0")
		var k := clampf(_age / 0.16, 0.0, 1.0)
		if k < 1.0:
			var points := PackedVector2Array()
			for i in range(12):
				points.append(Vector2.from_angle(0.3 + PI * float(i) / 6.0) * (44.0 * (0.5 + k) if i % 2 == 0 else 14.0))
			draw_colored_polygon(points, Color(light, 1.0 - k))
			draw_circle(Vector2.ZERO, 20.0, Color(1, 1, 1, 1.0 - k))
		var rk := clampf(_age / 0.5, 0.0, 1.0)
		if rk < 1.0:
			var r := 26.0 + 40.0 * rk
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(gold, 1.0 - rk), 3.0)
			draw_arc(Vector2.ZERO, r * 0.82, 0.0, TAU, 48, Color(gold, 0.8 * (1.0 - rk)), 1.5)
			for i in range(12):
				var a := _age * 4.0 + TAU * float(i) / 12.0
				var p := Vector2.from_angle(a) * r * 0.91
				draw_circle(p, 2.2, Color(light, 1.0 - rk))
		var bk := clampf(_age / 0.35, 0.0, 1.0)
		if bk < 1.0:
			var y := -460.0 * bk * bk * bk
			draw_line(Vector2.ZERO, Vector2(0, y), Color(gold, 0.8 * (1.0 - bk)), 9.0 * (1.0 - bk) + 3.0)
			draw_circle(Vector2(0, y), 9.0 + 7.0 * bk, light)
		var sk := clampf(_age / 1.0, 0.0, 1.0)
		for i in range(7):
			var a := float(i) * 0.9
			var d := 34.0 * (0.4 + 0.6 * fmod(float(i) * 0.43, 1.0)) * (1.0 - pow(1.0 - sk, 3.0))
			draw_circle(Vector2(cos(a) * d, sin(a) * d * 0.7 - 30.0 * sk), (7.0 + 6.0 * fmod(float(i) * 0.61, 1.0)) * (0.6 + sk), Color(0.91, 0.86, 0.75, 0.5 * (1.0 - sk)))
