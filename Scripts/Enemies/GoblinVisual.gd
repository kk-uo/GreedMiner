class_name GoblinVisual
extends RefCounted

## Presentation-only drawing for the Verdant Planet goblins (art option A,
## "green-skin tribe"). Top-down, local +X faces the ship, flat style A:
## every part is a dark rim + base + lit top-left facet. Red eyes are the
## threat accent. Gameplay scripts only pass animation amounts in.
##
## - Goblin: knife in the right hand, slashes on attack.
## - Goblin Hunter: fur hood, quiver of spears on the back; pulls the spear
##   back before a throw, then follows through empty-handed.
## - Elite Goblin: big body, iron helmet with bone horns, iron shoulder pads,
##   wooden round shield in front + spiked club; bashes with the shield.

## Common goblins (Goblin, Hunter) are drawn this much smaller than their
## base geometry; Elite keeps full size so it stays visibly larger.
const COMMON_SCALE: float = 0.82

## Seconds an attack pose (slash, bash, throw follow-through) lasts.
const ATTACK_POSE_TIME: float = 0.4
## Seconds before a Hunter's throw in which it winds the spear back.
const WINDUP_TIME: float = 0.45

const SKIN: Array[Color] = [Palette.GOBLIN_SKIN_DARK, Palette.GOBLIN_SKIN, Palette.GOBLIN_SKIN_LIGHT]
const FUR: Array[Color] = [Color("4E3A28"), Palette.GOBLIN_FUR, Palette.GOBLIN_FUR_LIGHT]
const IRON: Array[Color] = [Palette.GOBLIN_IRON_DARK, Palette.GOBLIN_IRON, Palette.GOBLIN_IRON_LIGHT]

## Every goblin is recorded into this shared batch and submitted to its
## CanvasItem as a single triangle array (1 draw command instead of ~30).
static var _PEN := MeshBatch2D.new()


## 0..1 pose strength for a pose timer counting down from ATTACK_POSE_TIME:
## snaps in fast, then eases back.
static func attack_amount(time_left: float) -> float:
	if time_left <= 0.0:
		return 0.0
	var progress: float = 1.0 - time_left / ATTACK_POSE_TIME
	if progress < 0.2:
		return progress / 0.2
	return 1.0 - ease((progress - 0.2) / 0.8, 0.6)


## step: -1..1 walk cycle. attack: 0..1 knife slash.
## flag: flag bearer banner. origin / lift: visual offset and extra scale
## (used while a goblin flies through the air after being thrown).
static func draw_goblin(canvas: CanvasItem, facing: float, step: float, attack: float, flash: bool,
		flag: bool = false, origin: Vector2 = Vector2.ZERO, lift: float = 1.0) -> void:
	_draw_goblin(_PEN, facing, step, attack, flash, flag, origin, lift)
	_PEN.flush_to(canvas)


static func _draw_goblin(canvas: Object, facing: float, step: float, attack: float, flash: bool,
		flag: bool = false, origin: Vector2 = Vector2.ZERO, lift: float = 1.0) -> void:
	var scale := Vector2.ONE * COMMON_SCALE * lift
	# Hands hang at the body's sides and swing fore/aft opposite each other.
	var hand_r := Vector2(-1.0 + step * 4.0, 14.5).lerp(Vector2(13.0, 3.0), attack)
	var hand_l := Vector2(-1.0 - step * 4.0, -14.5).lerp(Vector2(5.0, -11.0), attack)
	var knife_angle: float = lerpf(0.1, -0.55, attack)
	var body := _ngon(Vector2(-3.0, 0.0), Vector2(9.0, 12.0), 10, 0.31)
	var head := _ngon(Vector2(3.0, 0.0), Vector2(8.0, 8.0), 9, 0.2)

	canvas.draw_set_transform(origin + Palette.SHADOW_OFFSET * 0.8 * lift * lift, facing, scale)
	for shape in [body, head]:
		canvas.draw_colored_polygon(shape, Palette.SHADOW_COLOR)

	canvas.draw_set_transform(origin, facing, scale)
	if flag:
		_flag(canvas, flash)
	_fill(canvas, PackedVector2Array([Vector2(-12, -4), Vector2(-17, -2), Vector2(-17, 3), Vector2(-12, 5)]), Palette.GOBLIN_LEATHER, flash)
	_arm(canvas, Vector2(-2.0, -9.0), hand_l, 3.2, flash)
	_arm(canvas, Vector2(-2.0, 9.0), hand_r, 3.2, flash)
	_shade(canvas, body, SKIN, flash)
	_strap(canvas, Vector2(-3.0, 0.0), 9.0, 12.0, flash)
	_knife(canvas, hand_r, knife_angle, flash)
	_hand(canvas, hand_l, 2.6, flash)
	_hand(canvas, hand_r, 2.6, flash)
	_head(canvas, 3.0, 8.0, 1.15, step, flash)
	if attack > 0.3 and not flash:
		canvas.draw_arc(Vector2(6.0, 4.0), 18.0, -0.55, 0.95, 10, Color(1, 1, 1, 0.55 * attack), 2.0)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## windup: 0..1 spear pulled back before a throw. follow: 0..1 empty-handed
## follow-through right after a throw.
static func draw_hunter(canvas: CanvasItem, facing: float, step: float, windup: float, follow: float, flash: bool) -> void:
	_draw_hunter(_PEN, facing, step, windup, follow, flash)
	_PEN.flush_to(canvas)


static func _draw_hunter(canvas: Object, facing: float, step: float, windup: float, follow: float, flash: bool) -> void:
	var body := _ngon(Vector2(-3.0, 0.0), Vector2(9.0, 12.0), 10, 0.31)
	var head := _ngon(Vector2(3.0, 0.0), Vector2(7.6, 7.6), 9, 0.2)
	var hood := _ngon(Vector2(-6.0, 0.0), Vector2(9.0, 13.0), 9, 0.2)
	var hand_r := Vector2(6.0 + step * 2.0, 12.0)
	if follow > 0.0:
		hand_r = hand_r.lerp(Vector2(15.0, 6.0), follow)
	else:
		hand_r = hand_r.lerp(Vector2(-13.0, 13.0), windup)
	var hand_l := Vector2(-1.0 - step * 4.0, -14.5).lerp(Vector2(14.0, -6.0), maxf(windup, follow))

	canvas.draw_set_transform(Palette.SHADOW_OFFSET * 0.8, facing, Vector2.ONE * COMMON_SCALE)
	for shape in [hood, body, head]:
		canvas.draw_colored_polygon(shape, Palette.SHADOW_COLOR)

	canvas.draw_set_transform(Vector2.ZERO, facing, Vector2.ONE * COMMON_SCALE)
	for offset in [-4.0, 0.0, 4.0]:
		_spear(canvas, Vector2(-20.0, offset - 6.0), 0.42, 18.0, flash)
	_shade(canvas, hood, FUR, flash, 0.85)
	_arm(canvas, Vector2(-2.0, -9.0), hand_l, 3.0, flash)
	_arm(canvas, Vector2(-2.0, 9.0), hand_r, 3.0, flash)
	_shade(canvas, body, SKIN, flash)
	_strap(canvas, Vector2(-3.0, 0.0), 9.0, 12.0, flash)
	if follow <= 0.0:
		_spear(canvas, Vector2(hand_r.x - lerpf(16.0, 6.0, windup), hand_r.y + 0.5), lerpf(-0.03, -0.04, windup), 40.0, flash)
	_hand(canvas, hand_l, 2.5, flash)
	_hand(canvas, hand_r, 2.5, flash)
	_head(canvas, 3.0, 7.6, 1.15, step, flash)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## bash: 0..1 shield shoved forward.
static func draw_elite(canvas: CanvasItem, facing: float, step: float, bash: float, flash: bool) -> void:
	_draw_elite(_PEN, facing, step, bash, flash)
	_PEN.flush_to(canvas)


static func _draw_elite(canvas: Object, facing: float, step: float, bash: float, flash: bool) -> void:
	var push: float = bash * 6.0
	var body := _ngon(Vector2(-4.0, 0.0), Vector2(14.0, 20.0), 10, 0.31)
	var head := _ngon(Vector2(6.0, 0.0), Vector2(11.0, 11.0), 9, 0.2)
	var shield := _arc_band(Vector2(-4.0 + push, 0.0), 21.0, 26.0, -1.25, 0.45, 10)
	var hand_r := Vector2(6.0 + step * 3.0, 20.0).lerp(Vector2(-6.0, 21.0), bash)
	var hand_l := Vector2(13.0 + push, -12.0)
	var club_angle: float = lerpf(-0.2, 0.6, bash)

	canvas.draw_set_transform(Palette.SHADOW_OFFSET, facing, Vector2.ONE)
	for shape in [body, head, shield]:
		canvas.draw_colored_polygon(shape, Palette.SHADOW_COLOR)

	canvas.draw_set_transform(Vector2.ZERO, facing, Vector2.ONE)
	_arm(canvas, Vector2(-3.0, 15.0), hand_r, 5.0, flash)
	_club(canvas, hand_r, club_angle, flash)
	_arm(canvas, Vector2(-3.0, -15.0), hand_l, 5.0, flash)
	_shade(canvas, body, SKIN, flash)
	_strap(canvas, Vector2(-4.0, 0.0), 14.0, 20.0, flash)
	for side in [-1.0, 1.0]:
		_shade(canvas, _ngon(Vector2(-4.0, 15.0 * side), Vector2(6.5, 5.5), 7, 0.1), IRON, flash, 0.8)
	_hand(canvas, hand_r, 3.8, flash)
	_head(canvas, 6.0, 11.0, 1.0, step, flash)
	# Iron helmet over the back of the head, bone horns.
	var cap := _clip(_ngon(Vector2(6.0, 0.0), Vector2(11.2, 11.2), 9, 0.2), Vector2.RIGHT, 5.5)
	_shade(canvas, cap, IRON, flash, 0.85)
	_fill(canvas, PackedVector2Array([Vector2(3, -10), Vector2(-6, -16), Vector2(1, -8.5)]), Palette.GOBLIN_BONE, flash)
	_fill(canvas, PackedVector2Array([Vector2(3, 10), Vector2(1, 8.5), Vector2(-6, 16)]), Palette.GOBLIN_BONE, flash)
	_shield(canvas, Vector2(-4.0 + push, 0.0), 21.0, 26.0, -1.25, 0.45, flash)
	_hand(canvas, hand_l, 3.6, flash)
	if bash > 0.3 and not flash:
		for index in range(3):
			var angle: float = -1.0 + index * 0.5
			var direction := Vector2.RIGHT.rotated(angle)
			var origin := Vector2(-4.0 + push, 0.0)
			canvas.draw_line(origin + direction * 30.0, origin + direction * 36.0, Color(1, 1, 1, 0.5 * bash), 1.6)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Goblin Giant Chariot: two medium armoured war boars pull a catapult
## wagon. A goblin chieftain holds the reins, a cage of goblin "ammo" sits at
## the back and the catapult arm hurls them. Local +X faces the ship; the
## node origin is the middle of the whole rig (boars in front, wagon behind).
## roll: distance travelled (wheels, boar trot). throw: 0..1 throw animation
## progress (arm winds back). release: 0..1 after the goblins left (arm flings
## forward). berserk: boars charge with red eyes, snorting, speed lines.
## Whole rig is drawn this much larger than its base geometry.
const CHARIOT_SCALE: float = 1.25
## Base-geometry distance from the origin to the boars' snouts.
const CHARIOT_BASE_FRONT: float = 138.0
const CHARIOT_FRONT_REACH: float = CHARIOT_BASE_FRONT * CHARIOT_SCALE
## Rear axle: the wagon pivots here when its front kicks up.
const CHARIOT_TILT_PIVOT := Vector2(-110.0, 0.0)

## tilt: -0.3..1 front of the wagon kicking up (1 = highest) after a throw.
static func draw_chariot(canvas: CanvasItem, facing: float, roll: float, throw: float, release: float,
		berserk: bool, time: float, flash: bool, tilt: float = 0.0) -> void:
	_draw_chariot(_PEN, facing, roll, throw, release, berserk, time, flash, tilt)
	_PEN.flush_to(canvas)


static func _draw_chariot(canvas: Object, facing: float, roll: float, throw: float, release: float,
		berserk: bool, time: float, flash: bool, tilt: float = 0.0) -> void:
	var wood: Array[Color] = [Palette.GOBLIN_WOOD_DARK, Palette.GOBLIN_WOOD, Palette.GOBLIN_WOOD_LIGHT]
	var old_wood: Array[Color] = [Color("33251A"), Color("7A4F2E"), Color("9C6B3E")]
	var windup: float = clampf(throw / 0.75, 0.0, 1.0) if release <= 0.0 else 0.0
	var shake := Vector2.ZERO
	if windup > 0.6:
		shake = Vector2(sin(time * 60.0), cos(time * 47.0)) * 1.6 * windup
	var trot: float = sin(roll * 0.18)
	var g: float = CHARIOT_SCALE
	var wagon := Rect2(-132.0, -50.0, 140.0, 100.0)

	# Ground shadow (stays on the ground while the wagon tips up).
	canvas.draw_set_transform(Palette.SHADOW_OFFSET * 1.8, facing, Vector2.ONE * g)
	canvas.draw_colored_polygon(Palette.rounded_rect_points(wagon.grow(6.0), 14.0), Palette.SHADOW_COLOR)
	for y in [-30.0, 30.0]:
		canvas.draw_colored_polygon(_ngon(Vector2(64.0, y), Vector2(42.0, 22.0), 12, 0.0), Palette.SHADOW_COLOR)
	if tilt > 0.05:
		canvas.draw_colored_polygon(_ngon(Vector2(-20.0, 0.0), Vector2(40.0, 46.0), 12, 0.0), Color(0, 0, 0, 0.18 * tilt))

	canvas.draw_set_transform(shake, facing, Vector2.ONE * g)
	if berserk and not flash:
		for index in range(6):
			var y: float = -50.0 + index * 20.0
			var length: float = 26.0 + 12.0 * sin(time * 9.0 + index * 1.7)
			canvas.draw_line(Vector2(-140.0, y), Vector2(-140.0 - length, y), Color(Palette.GOBLIN_EYE, 0.55), 2.4)

	# Boars stay on the ground; everything on the wagon pivots on the rear axle.
	for index in range(2):
		var y: float = -30.0 if index == 0 else 30.0
		var gait: float = trot * (1.0 if index == 0 else -1.0)
		_war_boar(canvas, Vector2(68.0, y), gait, berserk, time + index * 0.7, flash)

	var lift: float = 1.0 + 0.16 * tilt
	var pivot_world: Vector2 = shake + (CHARIOT_TILT_PIVOT * (1.0 - lift) * g).rotated(facing)
	canvas.draw_set_transform(pivot_world, facing, Vector2.ONE * g * lift)

	# Reins + yoke.
	if not flash:
		for y in [-30.0, 30.0]:
			canvas.draw_line(Vector2(-8.0, y * 0.3), Vector2(46.0, y * 0.9), Palette.GOBLIN_LEATHER, 2.0)
	_shade(canvas, Palette.rounded_rect_points(Rect2(14.0, -50.0, 10.0, 100.0), 4.0), old_wood, flash, 0.8)

	# Wheels (one front wheel cracked).
	for index in range(4):
		var wheel: Vector2 = [Vector2(-104.0, -62.0), Vector2(-26.0, -62.0), Vector2(-104.0, 62.0), Vector2(-26.0, 62.0)][index]
		var rect := Rect2(wheel - Vector2(22.0, 9.0), Vector2(44.0, 18.0))
		_fill(canvas, Palette.rounded_rect_points(rect, 6.0), Palette.MECH, flash)
		if not flash:
			for tread in range(6):
				var x: float = rect.position.x + fposmod(float(tread) * 7.4 - roll * 1.2, 44.0)
				canvas.draw_line(Vector2(x, rect.position.y + 2.0), Vector2(x, rect.end.y - 2.0), Palette.MECH_LIGHT, 1.8)
			canvas.draw_circle(wheel, 4.2, Palette.GOBLIN_IRON)
			canvas.draw_circle(wheel, 2.0, Palette.GOBLIN_IRON_LIGHT)
			if index == 1:
				canvas.draw_colored_polygon(PackedVector2Array([wheel + Vector2(8.0, -9.0), wheel + Vector2(16.0, -9.0), wheel + Vector2(11.0, -3.0)]), Color("1A1512"))
		if berserk and not flash:
			for side in [-1.0, 1.0]:
				canvas.draw_colored_polygon(PackedVector2Array([wheel + Vector2(-4.0, side * 9.0), wheel + Vector2(0.0, side * 17.0), wheel + Vector2(4.0, side * 9.0)]), Palette.GOBLIN_IRON_LIGHT)

	# Battered wagon bed: chipped corners, a broken-out plank, cracks, patches.
	var bed := PackedVector2Array([
		Vector2(-118.0, -50.0), Vector2(-40.0, -50.0), Vector2(-34.0, -45.0), Vector2(-26.0, -50.0),
		Vector2(-6.0, -50.0), Vector2(8.0, -36.0), Vector2(8.0, 38.0), Vector2(-4.0, 50.0),
		Vector2(-74.0, 50.0), Vector2(-80.0, 44.0), Vector2(-88.0, 50.0), Vector2(-122.0, 50.0),
		Vector2(-132.0, 38.0), Vector2(-127.0, 20.0), Vector2(-132.0, 12.0), Vector2(-132.0, -38.0),
	])
	_shade(canvas, bed, old_wood, flash, 0.95)
	if not flash:
		for x in [-108.0, -84.0, -60.0, -36.0, -12.0]:
			canvas.draw_line(Vector2(x, -47.0), Vector2(x, 47.0), Color("33251A"), 1.6)
		# Broken-out plank showing the dark underside.
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-84.0, 18.0), Vector2(-61.0, 22.0), Vector2(-60.0, 47.0), Vector2(-84.0, 47.0), Vector2(-79.0, 34.0)]), Color("1A1512"))
		for spike in [Vector2(-80.0, 20.0), Vector2(-70.0, 21.0), Vector2(-64.0, 22.0)]:
			canvas.draw_colored_polygon(PackedVector2Array([spike + Vector2(-3.0, 0.0), spike + Vector2(1.0, 7.0), spike + Vector2(3.0, 0.0)]), Color("7A4F2E"))
		# Cracks.
		for crack in [[Vector2(-30.0, -44.0), Vector2(-24.0, -30.0), Vector2(-28.0, -18.0), Vector2(-20.0, -6.0)],
				[Vector2(-118.0, 24.0), Vector2(-104.0, 30.0), Vector2(-96.0, 42.0)],
				[Vector2(-6.0, 22.0), Vector2(-14.0, 34.0), Vector2(-10.0, 44.0)]]:
			canvas.draw_polyline(PackedVector2Array(crack), Color("1A1512"), 1.6)
		# Patches nailed over holes.
		for patch in [Rect2(-50.0, -44.0, 18.0, 14.0), Rect2(-122.0, -30.0, 14.0, 20.0)]:
			canvas.draw_colored_polygon(Palette.rounded_rect_points(patch, 2.0), Color("A88456"))
			for corner in [patch.position + Vector2(2.5, 2.5), patch.end - Vector2(2.5, 2.5)]:
				canvas.draw_circle(corner, 1.2, Palette.GOBLIN_IRON_DARK)
		# Bent, broken iron bands.
		canvas.draw_line(Vector2(-118.0, -47.0), Vector2(-46.0, -47.0), Palette.GOBLIN_IRON_DARK, 4.0)
		canvas.draw_line(Vector2(-22.0, -47.0), Vector2(-4.0, -47.0), Palette.GOBLIN_IRON_DARK, 4.0)
		canvas.draw_line(Vector2(-120.0, 47.0), Vector2(-92.0, 47.0), Palette.GOBLIN_IRON_DARK, 4.0)
		canvas.draw_polyline(PackedVector2Array([Vector2(-70.0, 47.0), Vector2(-30.0, 47.0), Vector2(-22.0, 52.0)]), Palette.GOBLIN_IRON_DARK, 4.0)
		# Arrows stuck in the wagon.
		for arrow in [[Vector2(-40.0, 30.0), -2.4], [Vector2(-96.0, -40.0), 2.2], [Vector2(-2.0, -24.0), -2.8]]:
			var base: Vector2 = arrow[0]
			var tail: Vector2 = base + Vector2.RIGHT.rotated(arrow[1]) * 14.0
			canvas.draw_line(base, tail, Palette.GOBLIN_WOOD_LIGHT, 1.6)
			canvas.draw_colored_polygon(PackedVector2Array([tail, tail + Vector2.RIGHT.rotated(arrow[1] + 0.5) * 5.0, tail + Vector2.RIGHT.rotated(arrow[1] - 0.5) * 5.0]), Palette.GOBLIN_CLOTH)

	# Goblin ammo cage at the back.
	var cage := Vector2(-108.0, 0.0)
	_shade(canvas, _ngon(cage, Vector2(20.0, 28.0), 10, 0.2), [Palette.GOBLIN_WOOD_DARK, Palette.GOBLIN_LEATHER, Palette.GOBLIN_FUR_LIGHT], flash, 0.84)
	if not flash:
		for head in [Vector2(-6.0, -15.0), Vector2(6.0, -7.0), Vector2(-7.0, 2.0), Vector2(6.0, 10.0), Vector2(-3.0, 19.0)]:
			_ammo_head(canvas, cage + head, 5.0)
		for index in range(5):
			var x: float = cage.x - 16.0 + index * 8.0
			canvas.draw_line(Vector2(x, -24.0), Vector2(x, 24.0), Palette.GOBLIN_WOOD_DARK, 1.6)

	# Big catapult: A-frame, rope torsion bundle, long arm with a big bucket.
	var pivot := Vector2(-58.0, 0.0)
	for side in [-1.0, 1.0]:
		_shade(canvas, PackedVector2Array([pivot + Vector2(-6.0, side * 4.0), pivot + Vector2(6.0, side * 4.0), pivot + Vector2(10.0, side * 40.0), pivot + Vector2(-10.0, side * 40.0)]), old_wood, flash, 0.8)
	var angle: float = lerpf(PI * 0.9, PI * 1.08, windup)
	if release > 0.0:
		angle = lerpf(PI * 1.08, PI * 0.06, ease(release, 0.4))
	var tip: Vector2 = pivot + Vector2.RIGHT.rotated(angle) * 92.0
	var side := Vector2.RIGHT.rotated(angle + PI * 0.5)
	_shade(canvas, PackedVector2Array([pivot + side * 8.0, tip + side * 5.5, tip - side * 5.5, pivot - side * 8.0]), wood, flash, 0.75)
	if not flash:
		for k in [0.3, 0.55, 0.8]:
			var band: Vector2 = pivot + (tip - pivot) * k
			canvas.draw_line(band + side * 7.0, band - side * 7.0, Palette.GOBLIN_IRON_DARK, 2.4)
	_shade(canvas, _ngon(tip, Vector2(22.0, 22.0), 9, angle), [Palette.GOBLIN_WOOD_DARK, Palette.GOBLIN_LEATHER, Palette.GOBLIN_FUR_LIGHT], flash, 0.82)
	if not flash and release <= 0.0:
		for head in [Vector2(-6.0, -6.0), Vector2(6.0, -4.0), Vector2(-5.0, 7.0), Vector2(6.0, 7.0), Vector2(0.0, 0.0)]:
			_ammo_head(canvas, tip + head, 4.8)
	_shade(canvas, _ngon(pivot, Vector2(14.0, 14.0), 10, 0.0), [Color("6B5A3A"), Color("A08A5A"), Color("C9B07A")], flash, 0.8)
	if not flash:
		for ring in [6.0, 10.0]:
			canvas.draw_arc(pivot, ring, 0.0, TAU, 16, Color("6B5A3A"), 1.4)
	_shade(canvas, _ngon(pivot, Vector2(5.0, 5.0), 8, 0.0), IRON, flash, 0.8)

	# Chieftain driver at the front of the wagon.
	var driver := Vector2(-16.0, 0.0)
	_shade(canvas, _ngon(driver + Vector2(-4.0, 0.0), Vector2(13.0, 18.0), 10, 0.31), SKIN, flash)
	for side_y in [-1.0, 1.0]:
		_shade(canvas, _ngon(Vector2(driver.x - 4.0, side_y * 16.0), Vector2(6.5, 5.5), 7, 0.1), IRON, flash, 0.8)
	_head(canvas, driver.x + 6.0, 11.0, 1.0, 0.0, flash)
	var cap := _clip(_ngon(Vector2(driver.x + 6.0, 0.0), Vector2(11.2, 11.2), 9, 0.2), Vector2.RIGHT, driver.x + 5.0)
	_shade(canvas, cap, IRON, flash, 0.85)
	if berserk and not flash:
		for y in [-4.2, 4.2]:
			canvas.draw_circle(Vector2(driver.x + 11.5, y), 4.0, Color(Palette.GOBLIN_EYE, 0.35))

	# Tattered tribal banner on the back corner.
	if not flash:
		var pole := Vector2(-126.0, -44.0)
		var top := Vector2(-150.0, -70.0)
		canvas.draw_line(pole, top, Palette.GOBLIN_WOOD_DARK, 3.0)
		canvas.draw_colored_polygon(PackedVector2Array([top, top + Vector2(-24.0, 4.0), top + Vector2(-16.0, 9.0), top + Vector2(-22.0, 13.0), top + Vector2(-14.0, 16.0), top + Vector2(-20.0, 22.0), top + Vector2(2.0, 16.0)]), Palette.GOBLIN_CLOTH)
		canvas.draw_circle(top + Vector2(-9.0, 9.0), 4.0, Palette.GOBLIN_BONE)
		canvas.draw_circle(top + Vector2(-9.0, 9.0), 1.6, Palette.GOBLIN_CLOTH)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## One armoured war boar (top-down, facing +X) centred at c.
static func _war_boar(canvas: Object, c: Vector2, gait: float, berserk: bool, time: float, flash: bool) -> void:
	var fur: Array[Color] = [Color("4E3726"), Palette.GOBLIN_FUR, Palette.GOBLIN_FUR_LIGHT]
	var snout_tones: Array[Color] = [Color("A0705C"), Color("C98F78"), Color("E3A990")]
	# Legs (trotting).
	for leg in [Vector2(18.0, -1.0), Vector2(-16.0, -1.0), Vector2(18.0, 1.0), Vector2(-16.0, 1.0)]:
		var swing: float = gait * 5.0 * (1.0 if leg.x * leg.y > 0.0 else -1.0)
		_fill(canvas, _ngon(c + Vector2(leg.x + swing, leg.y * 22.0), Vector2(6.0, 4.0), 8, 0.0), Color("3A2A1E"), flash)
	_shade(canvas, _ngon(c + Vector2(-4.0, 0.0), Vector2(36.0, 21.0), 12, 0.0), fur, flash, 0.88)
	if not flash:
		for index in range(5):
			var x: float = c.x - 26.0 + index * 9.0
			canvas.draw_line(Vector2(x, c.y - 4.0), Vector2(x - 6.0, c.y - 1.0), Color("3A2A1E"), 1.8)
			canvas.draw_line(Vector2(x, c.y + 4.0), Vector2(x - 6.0, c.y + 1.0), Color("3A2A1E"), 1.8)
		# Harness strap and saddle cloth.
		canvas.draw_line(Vector2(c.x - 2.0, c.y - 21.0), Vector2(c.x - 2.0, c.y + 21.0), Palette.GOBLIN_LEATHER, 5.0)
		canvas.draw_colored_polygon(_ngon(c + Vector2(-16.0, 0.0), Vector2(9.0, 12.0), 8, 0.0), Palette.GOBLIN_CLOTH)
	var head := c + Vector2(34.0, 0.0)
	for side in [-1.0, 1.0]:
		_fill(canvas, PackedVector2Array([head + Vector2(-8.0, side * 9.0), head + Vector2(-18.0, side * 20.0), head + Vector2(-2.0, side * 13.0)]), Color("4E3726"), flash)
	_shade(canvas, _ngon(head, Vector2(16.0, 15.0), 10, 0.2), fur, flash, 0.85)
	_shade(canvas, PackedVector2Array([head + Vector2(-6.0, -10.0), head + Vector2(6.0, -7.0), head + Vector2(6.0, 7.0), head + Vector2(-6.0, 10.0)]), IRON, flash, 0.8)
	_shade(canvas, _ngon(head + Vector2(15.0, 0.0), Vector2(8.0, 9.0), 8, 0.2), snout_tones, flash, 0.8)
	for side in [-1.0, 1.0]:
		_shade(canvas, PackedVector2Array([head + Vector2(8.0, side * 6.0), head + Vector2(24.0, side * 16.0), head + Vector2(21.0, side * 19.0), head + Vector2(5.0, side * 10.0)]),
				[Color("B8AE96"), Palette.GOBLIN_BONE, Color("FFF8EA")], flash, 0.7)
	if flash:
		return
	for side in [-1.0, 1.0]:
		canvas.draw_circle(head + Vector2(19.0, side * 3.0), 1.6, Color("3A2219"))
		var eye := head + Vector2(5.0, side * 8.0)
		var r: float = 3.0 if berserk else 2.2
		canvas.draw_circle(eye, r + 1.4, Color(Palette.GOBLIN_EYE, 0.35))
		canvas.draw_circle(eye, r, Palette.GOBLIN_EYE)
	if berserk:
		for side in [-1.0, 1.0]:
			var k: float = fposmod(time * 1.6 + (0.5 if side > 0.0 else 0.0), 1.0)
			var puff := head + Vector2(26.0 + 16.0 * k, side * (5.0 + 6.0 * k))
			canvas.draw_circle(puff, 4.0 + 5.0 * k, Color(Palette.STONE_DUST, 0.7 * (1.0 - k)))


static func _ammo_head(canvas: Object, c: Vector2, r: float) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.2, -0.6) * r, c + Vector2(-1.9, -1.5) * r, c + Vector2(0.2, -0.9) * r]), Palette.GOBLIN_SKIN_DARK)
	canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.2, 0.6) * r, c + Vector2(-1.9, 1.5) * r, c + Vector2(0.2, 0.9) * r]), Palette.GOBLIN_SKIN_DARK)
	canvas.draw_circle(c, r, Palette.GOBLIN_SKIN_DARK)
	canvas.draw_circle(c + Vector2(-0.15, -0.2) * r, r * 0.78, Palette.GOBLIN_SKIN)
	canvas.draw_circle(c + Vector2(0.5, -0.35) * r, r * 0.2, Palette.GOBLIN_EYE)
	canvas.draw_circle(c + Vector2(0.5, 0.35) * r, r * 0.2, Palette.GOBLIN_EYE)


## Thrown Hunter spear (projectile), pointing along angle, with motion streaks.
static func draw_thrown_spear(canvas: CanvasItem, angle: float) -> void:
	_draw_thrown_spear(_PEN, angle)
	_PEN.flush_to(canvas)


static func _draw_thrown_spear(canvas: Object, angle: float) -> void:
	canvas.draw_set_transform(Palette.SHADOW_OFFSET * 0.6, angle, Vector2.ONE)
	canvas.draw_line(Vector2(-20.0, 0.0), Vector2(18.0, 0.0), Palette.SHADOW_COLOR, 2.0)
	canvas.draw_set_transform(Vector2.ZERO, angle, Vector2.ONE)
	for index in range(3):
		var y: float = -3.0 + index * 3.0
		canvas.draw_line(Vector2(-32.0 + index * 3.0, y), Vector2(-21.0 + index * 3.0, y), Color(1, 1, 1, 0.35), 1.2)
	_spear(canvas, Vector2(-20.0, 0.0), 0.0, 32.0, false)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ==========================================
# Parts
# ==========================================

## Flag bearer: a pole on the back with a red tribal banner (bone emblem).
static func _flag(canvas: Object, flash: bool) -> void:
	var base := Vector2(-8.0, -3.0)
	var top := Vector2(-30.0, -12.0)
	if flash:
		canvas.draw_line(base, top, Palette.HIT_FLASH, 3.0)
		return
	canvas.draw_line(base, top, Palette.GOBLIN_WOOD_DARK, 3.0)
	canvas.draw_line(base, top, Palette.GOBLIN_WOOD_LIGHT, 1.6)
	var banner := PackedVector2Array([top, top + Vector2(-20.0, 4.0), top + Vector2(-15.0, 11.0), top + Vector2(-21.0, 19.0), top + Vector2(3.0, 15.0)])
	canvas.draw_colored_polygon(banner, Palette.GOBLIN_CLOTH)
	canvas.draw_colored_polygon(PackedVector2Array([top, top + Vector2(-20.0, 4.0), top + Vector2(-15.0, 8.0), top + Vector2(1.0, 5.0)]), Palette.GOBLIN_CLOTH.lightened(0.18))
	canvas.draw_circle(top + Vector2(-8.0, 9.0), 3.6, Palette.GOBLIN_BONE)
	canvas.draw_circle(top + Vector2(-8.0, 9.0), 1.4, Palette.GOBLIN_CLOTH)
	canvas.draw_circle(top, 2.2, Palette.GOBLIN_IRON_LIGHT)


static func _head(canvas: Object, x: float, radius: float, ear_scale: float, step: float, flash: bool) -> void:
	var length: float = radius * ear_scale
	for side in [-1.0, 1.0]:
		var flap: float = step * side * 0.6
		var ear := PackedVector2Array([
			Vector2(x - radius * 0.1, side * radius * 0.55),
			Vector2(x - radius * 0.9 - length * 0.55 + flap, side * (radius + length)),
			Vector2(x + radius * 0.25, side * radius * 0.9),
		])
		_fill(canvas, ear, Palette.GOBLIN_SKIN_DARK, flash)
		if not flash:
			canvas.draw_colored_polygon(_shrink(ear, 0.62), Palette.GOBLIN_SKIN)
	_shade(canvas, _ngon(Vector2(x, 0.0), Vector2(radius, radius), 9, 0.2), SKIN, flash)
	if flash:
		return
	for side in [-1.0, 1.0]:
		_eye(canvas, Vector2(x + radius * 0.5, side * radius * 0.38), radius * 0.17)
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(x + radius * 0.75, -radius * 0.18), Vector2(x + radius * 1.32, 0.0), Vector2(x + radius * 0.75, radius * 0.18),
	]), Palette.GOBLIN_SKIN_DARK.lerp(Palette.GOBLIN_SKIN, 0.4))


static func _eye(canvas: Object, center: Vector2, radius: float) -> void:
	canvas.draw_circle(center, radius + 1.3, Color(Palette.GOBLIN_EYE, 0.35))
	canvas.draw_circle(center, radius, Palette.GOBLIN_EYE)


static func _arm(canvas: Object, shoulder: Vector2, hand: Vector2, width: float, flash: bool) -> void:
	if flash:
		canvas.draw_line(shoulder, hand, Palette.HIT_FLASH, width + 1.4)
		return
	canvas.draw_line(shoulder, hand, Palette.GOBLIN_SKIN_DARK, width + 1.4)
	canvas.draw_line(shoulder, hand, Palette.GOBLIN_SKIN, width)


static func _hand(canvas: Object, center: Vector2, radius: float, flash: bool) -> void:
	canvas.draw_circle(center, radius + 0.7, Palette.HIT_FLASH if flash else Palette.GOBLIN_SKIN_DARK)
	if not flash:
		canvas.draw_circle(center, radius, Palette.GOBLIN_SKIN)


## Leather strap across the chest.
static func _strap(canvas: Object, center: Vector2, radius_x: float, radius_y: float, flash: bool) -> void:
	if flash:
		return
	canvas.draw_line(center + Vector2(-radius_x * 0.6, -radius_y * 0.75), center + Vector2(radius_x * 0.55, radius_y * 0.75),
			Palette.GOBLIN_LEATHER, radius_x * 0.32)


static func _knife(canvas: Object, hand: Vector2, angle: float, flash: bool) -> void:
	var blade := _place(PackedVector2Array([Vector2(2.5, -1.5), Vector2(12.5, -1.8), Vector2(16.5, 0.0), Vector2(2.5, 1.5)]), hand, angle)
	var grip := _place(PackedVector2Array([Vector2(-2.5, -1.3), Vector2(2.5, -1.3), Vector2(2.5, 1.3), Vector2(-2.5, 1.3)]), hand, angle)
	_fill(canvas, blade, Palette.GOBLIN_IRON_DARK, flash)
	if not flash:
		canvas.draw_colored_polygon(_shrink(blade, 0.7), Palette.GOBLIN_BLADE)
	_fill(canvas, grip, Palette.GOBLIN_WOOD, flash)


static func _spear(canvas: Object, butt: Vector2, angle: float, length: float, flash: bool) -> void:
	var along := Vector2.RIGHT.rotated(angle)
	var tip_base: Vector2 = butt + along * length
	if flash:
		canvas.draw_line(butt, tip_base, Palette.HIT_FLASH, 3.0)
	else:
		canvas.draw_line(butt, tip_base, Palette.GOBLIN_WOOD_DARK, 3.0)
		canvas.draw_line(butt, tip_base, Palette.GOBLIN_WOOD_LIGHT, 1.8)
		canvas.draw_line(butt + along * length * 0.78, butt + along * length * 0.86, Palette.GOBLIN_CLOTH, 3.2)
	var tip := _place(PackedVector2Array([Vector2(0, -2.4), Vector2(7.5, 0), Vector2(0, 2.4), Vector2(-1.5, 0)]), tip_base, angle)
	_fill(canvas, tip, Palette.GOBLIN_IRON_DARK, flash)
	if not flash:
		canvas.draw_colored_polygon(_shrink(tip, 0.65), Palette.GOBLIN_IRON_LIGHT)


static func _club(canvas: Object, hand: Vector2, angle: float, flash: bool) -> void:
	var club := _place(PackedVector2Array([
		Vector2(0, -1.4), Vector2(12, -2.2), Vector2(19, -4.0), Vector2(21, 0), Vector2(19, 4.0), Vector2(12, 2.2), Vector2(0, 1.4),
	]), hand, angle)
	_fill(canvas, club, Palette.GOBLIN_WOOD_DARK, flash)
	if flash:
		return
	canvas.draw_colored_polygon(_shrink(club, 0.78), Palette.GOBLIN_WOOD_LIGHT)
	for distance in [13.0, 17.0]:
		canvas.draw_circle(hand + Vector2(distance, -3.3).rotated(angle), 0.9, Palette.GOBLIN_IRON_LIGHT)
		canvas.draw_circle(hand + Vector2(distance, 3.3).rotated(angle), 0.9, Palette.GOBLIN_IRON_LIGHT)


## Wooden round shield seen from above: a thick arc with an iron rim and boss.
static func _shield(canvas: Object, center: Vector2, inner: float, outer: float, from: float, to: float, flash: bool) -> void:
	_fill(canvas, _arc_band(center, inner, outer, from, to, 10), Palette.GOBLIN_WOOD_DARK, flash)
	if flash:
		return
	canvas.draw_colored_polygon(_arc_band(center, inner + 0.8, outer - 0.8, from + 0.04, to - 0.04, 10), Palette.GOBLIN_WOOD_LIGHT)
	for index in range(1, 4):
		var angle: float = lerpf(from, to, index / 4.0)
		var direction := Vector2.RIGHT.rotated(angle)
		canvas.draw_line(center + direction * (inner + 0.8), center + direction * (outer - 0.8), Palette.GOBLIN_WOOD, 1.0)
	var middle: float = (inner + outer) * 0.5
	var boss: Vector2 = center + Vector2.RIGHT.rotated((from + to) * 0.5) * middle
	canvas.draw_circle(boss, 3.2, Palette.GOBLIN_IRON_DARK)
	canvas.draw_circle(boss, 2.2, Palette.GOBLIN_IRON_LIGHT)
	for angle in [from + 0.05, to - 0.05]:
		canvas.draw_circle(center + Vector2.RIGHT.rotated(angle) * middle, 1.1, Palette.GOBLIN_IRON_LIGHT)


# ==========================================
# Geometry helpers
# ==========================================

## Flat style A: dark rim, base, lit top-left facet.
static func _shade(canvas: Object, points: PackedVector2Array, tones: Array[Color], flash: bool, inset: float = 0.82) -> void:
	if points.size() < 3:
		return
	if flash:
		canvas.draw_colored_polygon(points, Palette.HIT_FLASH)
		return
	canvas.draw_colored_polygon(points, tones[0])
	var inner := _shrink(points, inset)
	canvas.draw_colored_polygon(inner, tones[1])
	var center := _centroid(inner)
	var reach: float = 0.0
	for point in inner:
		reach = maxf(reach, point.distance_to(center))
	var normal := Vector2(0.707, 0.707)
	var facet := _clip(inner, normal, normal.dot(center) - reach * 0.2)
	if facet.size() >= 3:
		canvas.draw_colored_polygon(facet, tones[2])


static func _fill(canvas: Object, points: PackedVector2Array, color: Color, flash: bool) -> void:
	canvas.draw_colored_polygon(points, Palette.HIT_FLASH if flash else color)


static func _ngon(center: Vector2, radius: Vector2, sides: int, rotation: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(sides):
		var angle: float = rotation + TAU * float(index) / float(sides)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points


static func _arc_band(center: Vector2, inner: float, outer: float, from: float, to: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments + 1):
		points.append(center + Vector2.RIGHT.rotated(lerpf(from, to, float(index) / segments)) * outer)
	for index in range(segments + 1):
		points.append(center + Vector2.RIGHT.rotated(lerpf(to, from, float(index) / segments)) * inner)
	return points


static func _place(points: PackedVector2Array, origin: Vector2, angle: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(origin + point.rotated(angle))
	return result


static func _shrink(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	var center := _centroid(points)
	var result := PackedVector2Array()
	for point in points:
		result.append(center + (point - center) * amount + Vector2(-0.5, -0.7) * amount)
	return result


static func _centroid(points: PackedVector2Array) -> Vector2:
	var total := Vector2.ZERO
	for point in points:
		total += point
	return total / float(maxi(points.size(), 1))


## Keeps the part of a convex polygon where normal.dot(p) <= limit.
static func _clip(points: PackedVector2Array, normal: Vector2, limit: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	var count := points.size()
	for index in range(count):
		var a: Vector2 = points[index]
		var b: Vector2 = points[(index + 1) % count]
		var da: float = normal.dot(a) - limit
		var db: float = normal.dot(b) - limit
		if da <= 0.0:
			result.append(a)
		if (da <= 0.0) != (db <= 0.0):
			result.append(a.lerp(b, da / (da - db)))
	return result


# ==========================================
# Chariot defeat: wreck debris, fleeing boars, surrender flag
# ==========================================

## Seconds-scale damping of the flying wreck pieces (higher = stops sooner).
const WRECK_DAMPING: float = 2.6


## Builds the debris of a broken chariot in the chariot's base frame (+X =
## towards the ship, unscaled units). Each piece is a Dictionary:
## home (centre), vel, spin, hop (0..1 jump), shapes [[points, tones]],
## lines [[from, to, color, width]], dots [[center, radius, color]];
## points are relative to home.
static func build_chariot_wreck(rng: RandomNumberGenerator) -> Array:
	var old_wood: Array[Color] = [Color("33251A"), Color("7A4F2E"), Color("9C6B3E")]
	var wood: Array[Color] = [Palette.GOBLIN_WOOD_DARK, Palette.GOBLIN_WOOD, Palette.GOBLIN_WOOD_LIGHT]
	var tire: Array[Color] = [Color("1A1512"), Palette.MECH, Palette.MECH_LIGHT]
	var rope: Array[Color] = [Color("6B5A3A"), Color("A08A5A"), Color("C9B07A")]
	var cage_tones: Array[Color] = [Palette.GOBLIN_WOOD_DARK, Palette.GOBLIN_LEATHER, Palette.GOBLIN_FUR_LIGHT]
	var dark := Color("1A1512")
	var plank := Color("33251A")
	var iron := Palette.GOBLIN_IRON_DARK
	var pieces: Array = []

	# Wagon bed snapped into three chunks along jagged lines.
	var rear := PackedVector2Array([Vector2(-132, -38), Vector2(-118, -50), Vector2(-86, -50), Vector2(-80, -30), Vector2(-90, -8),
		Vector2(-82, 14), Vector2(-88, 50), Vector2(-122, 50), Vector2(-132, 38)])
	var mid := PackedVector2Array([Vector2(-86, -50), Vector2(-40, -50), Vector2(-34, -45), Vector2(-30, -24), Vector2(-40, -4),
		Vector2(-32, 20), Vector2(-40, 50), Vector2(-74, 50), Vector2(-80, 44), Vector2(-88, 50), Vector2(-82, 14), Vector2(-90, -8), Vector2(-80, -30)])
	var front := PackedVector2Array([Vector2(-34, -45), Vector2(-26, -50), Vector2(-6, -50), Vector2(8, -36), Vector2(8, 38),
		Vector2(-4, 50), Vector2(-40, 50), Vector2(-32, 20), Vector2(-40, -4), Vector2(-30, -24)])
	pieces.append(_wreck_piece(rng, rear, old_wood, 40.0, 70.0, 0.6, 0.3,
		[[Vector2(-108, -46), Vector2(-108, 46), plank, 1.6], [Vector2(-118, -47), Vector2(-90, -47), iron, 4.0], [Vector2(-128, 20), Vector2(-104, 30), dark, 1.6]], []))
	pieces.append(_wreck_piece(rng, mid, old_wood, 8.0, 18.0, 0.25, 0.15,
		[[Vector2(-60, -46), Vector2(-60, 46), plank, 1.6], [Vector2(-84, -47), Vector2(-46, -47), iron, 4.0], [Vector2(-70, 47), Vector2(-42, 47), iron, 4.0]],
		[[Vector2(-72, 30), 7.0, dark]]))
	pieces.append(_wreck_piece(rng, front, old_wood, 50.0, 80.0, 0.7, 0.35,
		[[Vector2(-12, -46), Vector2(-12, 46), plank, 1.6], [Vector2(-22, -47), Vector2(-4, -47), iron, 4.0], [Vector2(-6, 22), Vector2(-12, 40), dark, 1.6]], []))

	# Wheels fly off and keep spinning; one is split in half.
	var wheels := [Vector2(-104, -62), Vector2(-26, -62), Vector2(-104, 62), Vector2(-26, 62)]
	for index in range(4):
		var c: Vector2 = wheels[index]
		var rect := Rect2(c - Vector2(22, 9), Vector2(44, 18))
		if index == 1:
			rect = Rect2(c - Vector2(22, 9), Vector2(24, 18))
		pieces.append(_wreck_piece(rng, Palette.rounded_rect_points(rect, 6.0), tire, 120.0, 170.0, 5.0, 0.6,
			[], [[c, 4.2, Palette.GOBLIN_IRON], [c, 2.0, Palette.GOBLIN_IRON_LIGHT]]))

	# Catapult arm snapped in two: the beam and the bucket.
	var beam := PackedVector2Array([Vector2(-62, -8), Vector2(-112, -4), Vector2(-108, 6), Vector2(-58, 8)])
	pieces.append(_wreck_piece(rng, beam, wood, 60.0, 90.0, 2.0, 0.8,
		[[Vector2(-80, -7), Vector2(-80, 7), iron, 2.4], [Vector2(-98, -6), Vector2(-96, 6), iron, 2.4]], []))
	pieces.append(_wreck_piece(rng, _ngon(Vector2(-146, -12), Vector2(20, 18), 9, 0.4), cage_tones, 70.0, 100.0, 3.0, 1.0, [], []))
	for side in [-1.0, 1.0]:
		var leg := PackedVector2Array([Vector2(-64, side * 4.0), Vector2(-52, side * 4.0), Vector2(-48, side * 40.0), Vector2(-68, side * 40.0)])
		pieces.append(_wreck_piece(rng, leg, old_wood, 70.0, 100.0, 3.0, 0.6, [], []))
	pieces.append(_wreck_piece(rng, _ngon(Vector2(-58, 0), Vector2(14, 14), 10, 0.0), rope, 30.0, 50.0, 2.0, 0.5,
		[], [[Vector2(-58, 0), 5.0, Palette.GOBLIN_IRON]]))

	# Ammo cage cracked open.
	var cage := _clip(_ngon(Vector2(-108, 0), Vector2(20, 28), 10, 0.2), Vector2(0.6, 0.8), -84.0)
	pieces.append(_wreck_piece(rng, cage, cage_tones, 50.0, 80.0, 1.5, 0.5,
		[[Vector2(-120, -22), Vector2(-120, 18), Palette.GOBLIN_WOOD_DARK, 1.6], [Vector2(-112, -24), Vector2(-112, 10), Palette.GOBLIN_WOOD_DARK, 1.6]], []))

	# Yoke split in two halves.
	for side in [-1.0, 1.0]:
		var yoke := Palette.rounded_rect_points(Rect2(14.0, -50.0 if side < 0.0 else 2.0, 10.0, 48.0), 4.0)
		pieces.append(_wreck_piece(rng, yoke, old_wood, 60.0, 90.0, 3.0, 0.4, [], []))

	# The tribal banner falls flat.
	var pole := Vector2(-126, -44)
	var top := Vector2(-150, -70)
	var cloth := PackedVector2Array([top, top + Vector2(-24, 4), top + Vector2(-16, 9), top + Vector2(-22, 13), top + Vector2(-14, 16), top + Vector2(-20, 22), top + Vector2(2, 16)])
	var red: Array[Color] = [Color("7E2A1C"), Palette.GOBLIN_CLOTH, Color("D0644A")]
	pieces.append(_wreck_piece(rng, cloth, red, 40.0, 60.0, 1.2, 0.3, [[pole, top, Palette.GOBLIN_WOOD_DARK, 3.0]], []))

	# Splinters.
	for index in range(12):
		var c := Vector2(rng.randf_range(-128.0, 4.0), rng.randf_range(-46.0, 46.0))
		var a: float = rng.randf_range(0.0, TAU)
		var size: float = rng.randf_range(5.0, 10.0)
		var splinter := PackedVector2Array([c + Vector2.RIGHT.rotated(a) * size, c + Vector2.RIGHT.rotated(a + 2.6) * size * 0.35, c + Vector2.RIGHT.rotated(a - 2.6) * size * 0.35])
		pieces.append(_wreck_piece(rng, splinter, old_wood, 150.0, 260.0, 8.0, 1.0, [], []))
	return pieces


static func _wreck_piece(rng: RandomNumberGenerator, points: PackedVector2Array, tones: Array[Color], speed_min: float, speed_max: float,
		spin: float, hop: float, lines: Array, dots: Array) -> Dictionary:
	var home := _centroid(points)
	var away: Vector2 = home - Vector2(-62.0, 0.0)
	if away.length() < 1.0:
		away = Vector2.LEFT
	var vel: Vector2 = away.normalized().rotated(rng.randf_range(-0.45, 0.45)) * rng.randf_range(speed_min, speed_max) + Vector2(-18.0, 0.0)
	var relative := PackedVector2Array()
	for point in points:
		relative.append(point - home)
	var rel_lines: Array = []
	for line in lines:
		rel_lines.append([line[0] - home, line[1] - home, line[2], line[3]])
	var rel_dots: Array = []
	for dot in dots:
		rel_dots.append([dot[0] - home, dot[1], dot[2]])
	return {
		"home": home, "vel": vel, "spin": rng.randf_range(-spin, spin), "hop": hop,
		"shape": relative, "tones": tones, "lines": rel_lines, "dots": rel_dots,
	}


## Where a wreck piece comes to rest (chariot base frame).
static func wreck_rest_position(piece: Dictionary) -> Vector2:
	return piece["home"] + piece["vel"] / WRECK_DAMPING


## Draws the debris t seconds after the chariot broke. origin is the wreck's
## local origin; facing is the chariot's facing.
static func draw_chariot_wreck(canvas: CanvasItem, facing: float, pieces: Array, t: float) -> void:
	var g: float = CHARIOT_SCALE
	var travel: float = (1.0 - exp(-WRECK_DAMPING * t)) / WRECK_DAMPING
	var jump: float = sin(PI * clampf(t / 0.55, 0.0, 1.0))
	# Shadows first so no piece shades another.
	for piece in pieces:
		var lift: float = 1.0 + 0.35 * jump * float(piece["hop"])
		var pos: Vector2 = ((piece["home"] + piece["vel"] * travel) * g).rotated(facing)
		_PEN.draw_set_transform(pos + Palette.SHADOW_OFFSET * (1.0 + 3.0 * jump * float(piece["hop"])), facing + float(piece["spin"]) * travel, Vector2.ONE * g * lift)
		_PEN.draw_colored_polygon(piece["shape"], Palette.SHADOW_COLOR)
	for piece in pieces:
		var lift: float = 1.0 + 0.35 * jump * float(piece["hop"])
		var pos: Vector2 = ((piece["home"] + piece["vel"] * travel) * g).rotated(facing)
		_PEN.draw_set_transform(pos, facing + float(piece["spin"]) * travel, Vector2.ONE * g * lift)
		_shade(_PEN, piece["shape"], piece["tones"], false, 0.86)
		for line in piece["lines"]:
			_PEN.draw_line(line[0], line[1], line[2], line[3])
		for dot in piece["dots"]:
			_PEN.draw_circle(dot[0], dot[1], dot[2])
	_PEN.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_PEN.flush_to(canvas)


## One war boar running loose (no wagon), drawn at the canvas origin.
static func draw_war_boar(canvas: CanvasItem, facing: float, gait: float, time: float) -> void:
	_PEN.draw_set_transform(Palette.SHADOW_OFFSET * 1.4, facing, Vector2.ONE * CHARIOT_SCALE)
	_PEN.draw_colored_polygon(_ngon(Vector2(4.0, 0.0), Vector2(42.0, 22.0), 12, 0.0), Palette.SHADOW_COLOR)
	_PEN.draw_set_transform(Vector2.ZERO, facing, Vector2.ONE * CHARIOT_SCALE)
	_war_boar(_PEN, Vector2.ZERO, gait, false, time, false)
	_PEN.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_PEN.flush_to(canvas)


## White surrender flag pushed up out of the wreck by a goblin hand.
## base: where the pole leaves the debris; rise 0..1 how far it has come out;
## time drives the cloth waving. Drawn screen-up (as if standing up).
static func draw_surrender_flag(canvas: CanvasItem, base: Vector2, rise: float, time: float) -> void:
	if rise <= 0.0:
		return
	var height: float = 128.0 * ease(rise, 0.6)
	var sway: float = sin(time * 1.7) * 4.0 * rise
	var top: Vector2 = base + Vector2(sway, -height)
	var white: Color = Color("F6F3EA")
	var crease: Color = Color("D8D2C2")
	# Pole shadow on the ground.
	_PEN.draw_line(base, base + Vector2(height * 0.42, height * 0.16), Palette.SHADOW_COLOR, 5.0)
	# Cloth (unfurls once the pole is mostly out).
	var unfurl: float = clampf((rise - 0.35) / 0.65, 0.0, 1.0)
	if unfurl > 0.0:
		var width: float = 76.0 * ease(unfurl, 0.5)
		var depth: float = 48.0
		var top_edge := PackedVector2Array()
		var bottom_edge := PackedVector2Array()
		var steps: int = 8
		for index in range(steps + 1):
			var k: float = float(index) / float(steps)
			var x: float = width * k
			var wave: float = sin(time * 4.2 - k * 5.0) * 7.0 * k
			top_edge.append(top + Vector2(x, 3.0 + wave + 2.0 * k))
			bottom_edge.append(top + Vector2(x - 2.0 * k, 3.0 + depth + wave - 3.0 * k))
		var cloth := PackedVector2Array()
		cloth.append_array(top_edge)
		for index in range(steps, -1, -1):
			cloth.append(bottom_edge[index])
		_PEN.draw_colored_polygon(Palette.offset_points(cloth, Vector2(6.0, 10.0)), Palette.SHADOW_COLOR)
		_PEN.draw_colored_polygon(cloth, white)
		# Shaded lower fold following the wave.
		var fold := PackedVector2Array()
		for index in range(steps + 1):
			fold.append(top_edge[index].lerp(bottom_edge[index], 0.62))
		for index in range(steps, -1, -1):
			fold.append(bottom_edge[index])
		_PEN.draw_colored_polygon(fold, crease)
		_PEN.draw_line(top_edge[3], bottom_edge[3], Color(crease, 0.8), 1.4)
	# Pole + knob.
	_PEN.draw_line(base, top, Palette.GOBLIN_WOOD_DARK, 6.0)
	_PEN.draw_line(base, top, Palette.GOBLIN_WOOD, 3.6)
	_PEN.draw_circle(top, 4.4, Palette.GOBLIN_WOOD_LIGHT)
	# Little green hand gripping the pole at the debris.
	var grip: Vector2 = base.lerp(top, 0.12)
	_PEN.draw_circle(grip + Vector2(1.0, 1.0), 6.0, Palette.GOBLIN_SKIN_DARK)
	_PEN.draw_circle(grip, 5.0, Palette.GOBLIN_SKIN)
	_PEN.draw_circle(grip + Vector2(-1.5, -1.5), 2.0, Palette.GOBLIN_SKIN_LIGHT)
	_PEN.flush_to(canvas)


# ==========================================
# Goblin Engineer (throws dynamite)
# ==========================================

const DYNAMITE_RED := Color("C8372A")
const DYNAMITE_DARK := Color("8A2218")
const DYNAMITE_LIGHT := Color("E8604A")
const BRASS := Color("C9A24A")
const BRASS_DARK := Color("8A6A28")
const GLASS := Color("9FD8E8")


## windup: 0..1 dynamite pulled back before a throw; follow: 0..1 empty-handed
## follow-through. time drives the fuse spark flicker.
static func draw_engineer(canvas: CanvasItem, facing: float, step: float, windup: float, follow: float, flash: bool, time: float) -> void:
	_draw_engineer(_PEN, facing, step, windup, follow, flash, time)
	_PEN.flush_to(canvas)


static func _draw_engineer(canvas: Object, facing: float, step: float, windup: float, follow: float, flash: bool, time: float) -> void:
	var body := _ngon(Vector2(-3.0, 0.0), Vector2(9.0, 12.0), 10, 0.31)
	var head := _ngon(Vector2(3.0, 0.0), Vector2(7.6, 7.6), 9, 0.2)
	var pack := Palette.rounded_rect_points(Rect2(-17.0, -8.0, 9.0, 16.0), 2.5)
	var hand_l := Vector2(-1.0 - step * 4.0, -14.5).lerp(Vector2(10.0, -8.0), maxf(windup, follow))
	var hand_r := Vector2(-1.0 + step * 4.0, 14.5)
	if follow > 0.0:
		hand_r = hand_r.lerp(Vector2(15.0, 6.0), follow)
	else:
		hand_r = hand_r.lerp(Vector2(-12.0, 15.0), windup)

	canvas.draw_set_transform(Palette.SHADOW_OFFSET * 0.8, facing, Vector2.ONE * COMMON_SCALE)
	for shape in [pack, body, head]:
		canvas.draw_colored_polygon(shape, Palette.SHADOW_COLOR)

	canvas.draw_set_transform(Vector2.ZERO, facing, Vector2.ONE * COMMON_SCALE)
	# Satchel of dynamite on the back.
	_shade(canvas, pack, [Color("4A3222"), Palette.GOBLIN_LEATHER, Palette.GOBLIN_FUR_LIGHT], flash, 0.84)
	if not flash:
		for y in [-4.5, 0.0, 4.5]:
			var stick := Rect2(-21.0, y - 1.6, 7.0, 3.2)
			canvas.draw_colored_polygon(Palette.rounded_rect_points(stick, 1.2), DYNAMITE_RED)
			canvas.draw_line(Vector2(-21.0, y), Vector2(-23.5, y - 1.0), Palette.GOBLIN_BONE, 0.8)
	_arm(canvas, Vector2(-2.0, -9.0), hand_l, 3.0, flash)
	_arm(canvas, Vector2(-2.0, 9.0), hand_r, 3.0, flash)
	_shade(canvas, body, SKIN, flash)
	# Leather work apron with a brass buckle.
	if not flash:
		canvas.draw_colored_polygon(_ngon(Vector2(-1.0, 0.0), Vector2(6.0, 8.5), 8, 0.0), Palette.GOBLIN_LEATHER)
		canvas.draw_colored_polygon(Palette.rounded_rect_points(Rect2(-2.5, -1.8, 3.6, 3.6), 0.8), BRASS)
	if follow <= 0.0:
		_draw_dynamite_stick(canvas, hand_r + Vector2(1.5, 0.0), lerpf(0.0, 0.6, windup), flash, time)
	_hand(canvas, hand_l, 2.5, flash)
	_hand(canvas, hand_r, 2.5, flash)
	_head(canvas, 3.0, 7.6, 1.15, step, flash)
	# Brass goggles pushed up on the forehead (strap across the head).
	if not flash:
		canvas.draw_line(Vector2(-1.5, -7.2), Vector2(-1.5, 7.2), Color("3B2A1E"), 1.6)
		for side in [-1.0, 1.0]:
			var lens := Vector2(-1.0, side * 3.2)
			canvas.draw_circle(lens, 2.4, BRASS_DARK)
			canvas.draw_circle(lens, 1.8, BRASS)
			canvas.draw_circle(lens, 1.2, GLASS)
			canvas.draw_circle(lens + Vector2(-0.5, -0.5), 0.5, Color.WHITE)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## One dynamite stick centred at c, angle relative to the canvas transform,
## with a burning fuse at its back end.
static func _draw_dynamite_stick(canvas: Object, c: Vector2, angle: float, flash: bool, time: float) -> void:
	var along := Vector2.RIGHT.rotated(angle)
	var side := Vector2(-along.y, along.x)
	var half_len: float = 5.0
	var half_w: float = 1.9
	var body := PackedVector2Array([
		c - along * half_len - side * half_w, c + along * half_len - side * half_w,
		c + along * half_len + side * half_w, c - along * half_len + side * half_w,
	])
	_fill(canvas, body, DYNAMITE_DARK, flash)
	if flash:
		return
	canvas.draw_colored_polygon(PackedVector2Array([body[0], body[1], c + along * half_len, c - along * half_len]), DYNAMITE_LIGHT)
	canvas.draw_line(c - side * half_w, c + side * half_w, Palette.GOBLIN_BONE, 1.2)
	var fuse_end: Vector2 = c - along * (half_len + 3.0) + side * 1.2
	canvas.draw_line(c - along * half_len, fuse_end, Color("3B2A1E"), 0.9)
	var flicker: float = 0.6 + 0.4 * sin(time * 47.0)
	canvas.draw_circle(fuse_end, 2.4 * flicker + 0.6, Color(Palette.GOLD, 0.45))
	canvas.draw_circle(fuse_end, 1.1, Color("FFF4C2"))
	for index in range(3):
		var spark_angle: float = time * 13.0 + float(index) * 2.1
		canvas.draw_line(fuse_end, fuse_end + Vector2.RIGHT.rotated(spark_angle) * (2.0 + 1.5 * flicker), Palette.GOLD, 0.7)


## Dynamite in flight (local origin = stick), spinning, with its shadow on
## the ground at shadow_offset (height of the arc).
static func draw_dynamite(canvas: CanvasItem, spin: float, shadow_offset: Vector2, time: float) -> void:
	_PEN.draw_set_transform(shadow_offset, spin, Vector2.ONE)
	_PEN.draw_colored_polygon(Palette.rounded_rect_points(Rect2(-5.0, -2.0, 10.0, 4.0), 1.4), Palette.SHADOW_COLOR)
	_PEN.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * 1.25)
	_draw_dynamite_stick(_PEN, Vector2.ZERO, spin, false, time)
	_PEN.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_PEN.flush_to(canvas)
