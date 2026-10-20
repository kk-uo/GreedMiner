class_name MiningDrillVisual
extends RefCounted

## Presentation-only drill animation for MiningModule ("B v2" auger, style A).
##
## One cycle (CYCLE_TIME seconds) = three "bites" where the auger is pushed
## down, squashes and flings cutting chips, a short wind-up lift, then a hard
## breakthrough slam (white flash, shockwave ring, small vector shards, a big
## burst of black smoke) and finally the bit is yanked out with an ore nugget.
## A thick black smoke column rises from the exhaust pipe the whole time.
##
## Everything is drawn in module-local space. `up` is screen-up converted into
## module space so smoke rises straight up even on a 45° ship layout.
## No gameplay code depends on this file; ore production stays on MiningTimer.

const CYCLE_TIME: float = 2.4
const BITES: Array[float] = [0.0, 0.24, 0.48]
const BREAK: float = 0.72
const PIPE := Vector2(-15.0, -15.0)

const SMOKE_DEEP := Color("1F1B19")
const SMOKE_MID := Color("332D29")
const SMOKE_LIGHT := Color("4D4540")
const HOLE_TONES: Array[Color] = [Color("2F2A26"), Color("25211E"), Color("1C1916"), Color("141110"), Color("0D0B0A")]
const CHIP_COLORS: Array[Color] = [Color("CFC5B2"), Color("9A8F7C"), Color("6B5A4A")]
const FLASH := Color("FFF4E0")
const FLUTE := Color("8D857C")


## Random-but-stable particle layout for one module (call once in _ready).
static func make_particles(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var chips: Array = []
	for bite in range(BITES.size()):
		var row: Array = []
		for index in range(8):
			row.append({
				"angle": rng.randf_range(0.0, TAU),
				"speed": rng.randf_range(0.8, 1.3),
				"size": rng.randf_range(1.2, 2.2),
				"color": CHIP_COLORS[rng.randi() % CHIP_COLORS.size()],
			})
		chips.append(row)
	var shards: Array = []
	for index in range(18):
		shards.append({
			"angle": index * TAU / 18.0 + rng.randf_range(-0.15, 0.15),
			"speed": rng.randf_range(26.0, 48.0),
			"size": rng.randf_range(1.9, 3.0),
			"spin": rng.randf_range(-3.5, 3.5),
			"shape": index % 3,
			"color": Palette.ACCENT if index % 3 == 0 else [Palette.SHIP_BODY, Palette.SHIP_PART, CHIP_COLORS[1], CHIP_COLORS[2]][index % 4],
		})
	return {"chips": chips, "shards": shards}


# ==========================================
# Timeline
# ==========================================

## 0 = surface, 1 = deepest. Goes slightly negative when the bit is yanked out.
static func depth_at(t: float) -> float:
	var depth: float = 0.0
	for bite in BITES:
		depth += 0.22 * _smooth((t - bite - 0.02) / 0.06)
	if t >= 0.66 and t < BREAK:
		depth -= 0.12 * _smooth((t - 0.66) / 0.05)
	if t >= BREAK:
		depth = 0.66 + 0.34 * _smooth((t - BREAK) / 0.025)
	if t >= 0.8:
		depth = lerpf(1.0, -0.12, _smooth((t - 0.8) / 0.12))
		if t > 0.92:
			depth = lerpf(-0.12, 0.0, _smooth((t - 0.92) / 0.08))
	return depth


## 1 right when a bite lands, fading over a short moment.
static func bite_impulse(t: float) -> float:
	var amount: float = 0.0
	for bite in BITES:
		var age: float = t - bite - 0.02
		if age >= 0.0 and age < 0.12:
			amount = maxf(amount, 1.0 - age / 0.12)
	return amount


## 1 at the breakthrough slam, fading.
static func slam_amount(t: float) -> float:
	var age: float = t - BREAK
	return 1.0 - age / 0.16 if age >= 0.0 and age < 0.16 else 0.0


# ==========================================
# Module body (drawn on the module itself)
# ==========================================

## t: 0..1 cycle phase. active: false draws a resting drill (assembly, icons).
## impact: 0..1 Ore Burst click punch (drill shoved down, module jolts,
## white flash at the bit). Presentation only.
static func draw_module(canvas: CanvasItem, t: float, active: bool, particles: Dictionary, shadow_offset: Vector2, impact: float = 0.0) -> void:
	if not active:
		t = 0.0
	var depth: float = depth_at(t) if active else 0.0
	var impulse: float = bite_impulse(t) if active else 0.0
	var slam: float = slam_amount(t) if active else 0.0
	var shake := Vector2.ZERO
	if active and t < 0.95:
		var time: float = t * CYCLE_TIME
		shake = Vector2(sin(time * 375.0) * 0.8 * impulse + sin(time * 540.0) * 2.2 * slam,
				cos(time * 458.0) * (0.5 * impulse + 1.4 * slam))
	if impact > 0.0:
		shake += Vector2(sin(impact * 41.0) * 2.4, 1.8 + cos(impact * 37.0) * 0.8) * impact
	canvas.draw_set_transform(shake, 0.0, Vector2.ONE)

	var plate := Rect2(-22.0, -22.0, 44.0, 44.0)
	Palette.draw_rounded_rect(canvas, Rect2(plate.position + shadow_offset * 0.6, plate.size), 6.0, Palette.SHADOW_COLOR)
	Palette.draw_rounded_rect(canvas, plate, 6.0, Palette.SHIP_PART_EDGE)
	Palette.draw_rounded_rect(canvas, Rect2(-22.0, -22.0, 42.0, 41.0), 6.0, Palette.SHIP_PART)

	# Bore hole: rim + shafts that darken as the bit goes deeper.
	var dig: float = clampf(depth, 0.0, 1.0)
	canvas.draw_circle(Vector2.ZERO, 19.0, Palette.MECH_LIGHT)
	canvas.draw_circle(Vector2.ZERO, 17.5, Palette.MECH)
	for index in range(HOLE_TONES.size()):
		var radius: float = 17.5 - (index + 1) * 2.6 * (0.35 + 0.65 * dig)
		canvas.draw_circle(Vector2.ZERO, maxf(radius, 1.0), HOLE_TONES[index])

	var spin: float = t * TAU * (14.0 if t < 0.8 else 4.0) if active else 0.4
	# White motion arcs around the spinning bit.
	if active:
		var arc_radius: float = 16.5 * (1.0 - 0.32 * dig)
		for index in range(3):
			var from: float = spin + index * TAU / 3.0
			canvas.draw_arc(Vector2.ZERO, arc_radius, from, from + 0.9, 6,
					Color(Palette.SHIP_BODY, 0.55 if t < 0.8 else 0.2), 1.3)

	var size: float = (1.0 - 0.34 * depth) * (1.0 - 0.06 * impulse) * (1.0 - 0.2 * impact)
	_draw_bit(canvas, spin, size, maxf(-depth, 0.0) * 3.0, dig * 0.85, shadow_offset, shake)
	if impact > 0.0:
		canvas.draw_set_transform(shake, 0.0, Vector2.ONE)
		canvas.draw_circle(Vector2.ZERO, 9.0 + 9.0 * (1.0 - impact), Color(FLASH, 0.75 * impact))
		canvas.draw_arc(Vector2.ZERO, 14.0 + 10.0 * (1.0 - impact), 0.0, TAU, 24, Color(Palette.GOLD_LIGHT, impact), 2.2)

	# Cutting chips flung along the spin direction on every bite.
	if active:
		var chips: Array = particles.get("chips", [])
		for bite_index in range(mini(chips.size(), BITES.size())):
			var age: float = (t - BITES[bite_index] - 0.02) / 0.2
			if age < 0.0 or age >= 1.0:
				continue
			for chip in chips[bite_index]:
				var k: float = clampf(age * float(chip["speed"]), 0.0, 1.0)
				if k <= 0.0 or k >= 1.0:
					continue
				var angle: float = chip["angle"]
				var tangent: float = angle + 1.2
				var position := Vector2.RIGHT.rotated(angle) * 15.0 + Vector2.RIGHT.rotated(tangent) * 14.4 * _smooth(k)
				var chip_size: float = float(chip["size"]) * (1.0 - k * 0.6)
				var color: Color = chip["color"]
				color.a = pow(1.0 - k, 1.2)
				canvas.draw_set_transform(shake + position, angle + k * 7.0, Vector2.ONE)
				canvas.draw_colored_polygon(PackedVector2Array([
					Vector2(chip_size, 0.0), Vector2(-chip_size * 0.6, chip_size * 0.8), Vector2(-chip_size * 0.6, -chip_size * 0.8),
				]), color)
		canvas.draw_set_transform(shake, 0.0, Vector2.ONE)

	# Exhaust pipe the smoke column comes out of.
	Palette.draw_rounded_rect(canvas, Rect2(PIPE - Vector2(6.0, 6.0), Vector2(12.0, 12.0)), 3.0, Palette.MECH)
	canvas.draw_circle(PIPE, 3.5, Color("120F0D"))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _draw_bit(canvas: CanvasItem, spin: float, size: float, height: float, dark: float, shadow_offset: Vector2, shake: Vector2) -> void:
	var radius: float = 14.0 * size
	var gear := PackedVector2Array()
	for index in range(16):
		var angle: float = spin + PI * index / 8.0
		gear.append(Vector2.RIGHT.rotated(angle) * (radius if index % 2 == 0 else radius * 0.8))
	canvas.draw_set_transform(shake + shadow_offset * (0.6 + 1.4 * height), 0.0, Vector2.ONE)
	canvas.draw_colored_polygon(gear, Palette.SHADOW_COLOR)
	canvas.draw_set_transform(shake, 0.0, Vector2.ONE)
	canvas.draw_colored_polygon(gear, Palette.MECH)
	canvas.draw_circle(Vector2.ZERO, radius * 0.72, Palette.MECH_LIGHT)
	for flute in range(3):
		var start: float = spin + flute * TAU / 3.0
		var points := PackedVector2Array()
		for step in range(7):
			var progress: float = step / 6.0
			points.append(Vector2.RIGHT.rotated(start + progress * 1.9) * radius * (0.18 + 0.55 * progress))
		canvas.draw_polyline(points, FLUTE, 2.2 * size)
	canvas.draw_circle(Vector2.ZERO, radius * 0.22, Palette.ACCENT)
	canvas.draw_circle(Vector2.ONE * -radius * 0.07, radius * 0.09, Palette.ACCENT_LIGHT)
	if dark > 0.02:
		canvas.draw_circle(Vector2.ZERO, radius + 0.5, Color(0.0, 0.0, 0.0, 0.45 * dark))


# ==========================================
# Effects layer (smoke, shockwave, shards) — drawn above neighbouring modules
# ==========================================

## up: screen-up in module space. boost > 1 makes the breakthrough bigger
## (used when a mining QTE fires the drill).
static func draw_fx(canvas: CanvasItem, t: float, particles: Dictionary, up: Vector2, boost: float = 1.0) -> void:
	var side := Vector2(-up.y, up.x)          # screen-left
	var depth: float = clampf(depth_at(t), 0.0, 1.0)

	if t >= BREAK:
		var k: float = clampf((t - BREAK) / 0.28, 0.0, 1.0)
		canvas.draw_arc(Vector2.ZERO, (14.0 + 34.0 * _smooth(k)) * boost, 0.0, TAU, 40,
				Color(FLASH, (1.0 - k) * 0.9), 3.2 * (1.0 - k) + 0.4)
		if k < 0.25:
			canvas.draw_circle(Vector2.ZERO, 16.0 + 8.0 * k, Color(FLASH, 0.55 * (1.0 - k / 0.25)))
		_draw_shards(canvas, k, particles.get("shards", []), up, boost)
		for index in range(8):
			var angle: float = index * TAU / 8.0 + 0.3
			var distance: float = (18.0 + 18.0 * _smooth(k)) * boost
			_puff(canvas, Vector2.RIGHT.rotated(angle) * distance + up * 6.0 * k, 3.0 + 7.0 * k, 0.85 * pow(1.0 - k, 0.9))

	# Smoke column: thick, thicker the deeper the drill is.
	var thick: float = 0.5 + 0.5 * depth
	for index in range(10):
		var age: float = fposmod(t + index / 10.0, 1.0)
		var position: Vector2 = PIPE + up * 46.0 * age + side * 9.0 * age + side * 3.0 * sin(age * 9.0 + index)
		_puff(canvas, position, (3.0 + 11.0 * age) * thick + 1.5, 0.95 * (1.0 - age) * thick)
	# Extra puff on every bite, a big one on the breakthrough.
	var bursts: Array[float] = BITES.duplicate()
	bursts.append(BREAK)
	for burst in bursts:
		var age: float = fposmod(t - burst, 1.0)
		if age >= 0.35:
			continue
		var k: float = age / 0.35
		var big: float = 1.6 * boost if is_equal_approx(burst, BREAK) else 1.0
		_puff(canvas, PIPE + side * (4.0 + 6.0 * k) + up * (6.0 + 26.0 * _smooth(k) * big), (5.0 + 9.0 * k) * big, 0.95 * (1.0 - k))

	# Ore nugget pulled out with the bit.
	if t >= 0.84:
		var k: float = clampf((t - 0.84) / 0.16, 0.0, 1.0)
		_nugget(canvas, -side * 16.0 * k + up * 26.0 * _smooth(k), 1.35, clampf(2.0 - 2.0 * k, 0.0, 1.0))


static func _draw_shards(canvas: CanvasItem, k: float, shards: Array, up: Vector2, boost: float) -> void:
	var alpha: float = clampf(1.25 - k * 1.15, 0.0, 1.0)
	if alpha <= 0.0:
		return
	for shard in shards:
		var angle: float = shard["angle"]
		var distance: float = (12.0 + float(shard["speed"]) * (1.0 - pow(1.0 - k, 2.4))) * boost
		var position := Vector2.RIGHT.rotated(angle) * distance + up * 8.0 * k * k
		var size: float = float(shard["size"]) * (1.0 - 0.5 * k)
		var color: Color = shard["color"]
		color.a = alpha
		canvas.draw_set_transform(position, angle + k * float(shard["spin"]), Vector2.ONE)
		match int(shard["shape"]):
			0:
				canvas.draw_colored_polygon(PackedVector2Array([
					Vector2(size * 1.6, 0.0), Vector2(0.0, size * 0.7), Vector2(-size * 1.6, 0.0), Vector2(0.0, -size * 0.7),
				]), color)
			1:
				canvas.draw_colored_polygon(PackedVector2Array([
					Vector2(size, 0.0), Vector2(-size * 0.7, size * 0.9), Vector2(-size * 0.5, -size * 0.9),
				]), color)
			_:
				canvas.draw_line(Vector2(-size * 1.8, 0.0), Vector2(size * 1.8, 0.0), color, 1.3)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Flat smoke ball: dark base, mid body, lit top-left lobe.
static func _puff(canvas: CanvasItem, center: Vector2, radius: float, alpha: float) -> void:
	if alpha <= 0.01:
		return
	canvas.draw_circle(center, radius, Color(SMOKE_DEEP, alpha))
	canvas.draw_circle(center + Vector2(-0.18, -0.2) * radius, radius * 0.78, Color(SMOKE_MID, alpha * 0.85))
	canvas.draw_circle(center + Vector2(-0.35, -0.38) * radius, radius * 0.36, Color(SMOKE_LIGHT, alpha * 0.8))


static func _nugget(canvas: CanvasItem, center: Vector2, size: float, alpha: float) -> void:
	if alpha <= 0.01:
		return
	var top := center + Vector2(0.0, -5.0) * size
	var right := center + Vector2(4.0, 0.0) * size
	var bottom := center + Vector2(0.0, 5.0) * size
	var left := center + Vector2(-4.0, 0.0) * size
	canvas.draw_colored_polygon(PackedVector2Array([top, right, bottom, left]), Color(Palette.GOLD_SHADOW, alpha))
	canvas.draw_colored_polygon(PackedVector2Array([top, right, center + Vector2(0.0, 1.0) * size, left]), Color(Palette.GOLD, alpha))
	canvas.draw_colored_polygon(PackedVector2Array([top, center + Vector2(-1.5, -1.5) * size, left]), Color(Palette.GOLD_LIGHT, alpha))


static func _smooth(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)
