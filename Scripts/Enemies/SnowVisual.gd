extends RefCounted

## Presentation-only drawing for the Frozen Planet snow monsters (art option
## B, "ice-crystal yetis"). Top-down, local +X faces the ship, flat style A
## like the demons: shaggy white fur in three tones, a blue face and big blue
## fists, curled horns, glowing cyan eyes and cyan ice crystals on the
## shoulders and back. One hard shadow; a white flash when hit.
##
## - Snow Monster: the basic yeti; swings its fists while walking, punches.
## - Big Snow Monster: a bigger yeti carrying an ice club.
## - Sled Car: a wooden sled with four snow monsters riding it, drawn at the
##   same size as the ones on foot (they jump off when the sled breaks).
## - Snow Monster Wizard: thick nerdy goggles with spinning swirl lenses, an
##   open spell book in one fist and an ice-crystal staff in the other.
## - Mega Monster (boss): a huge yeti with an ice crown, ram horns, an ice
##   boulder on its back and a frost aura. Bursts out of a snow mound, rolls
##   and throws a freezing snowball, and when it is the last one left sits
##   down and cries, then enrages (red eyes, red glow, steam).
## Load with preload(); no class_name on purpose.

const FUR: Array[Color] = [Color("7F9DB3"), Color("BCD3E2"), Color("E8F3FA")]
const SKIN: Array[Color] = [Color("2F4E6B"), Color("4A7393"), Color("6E98B8")]
const HORN: Array[Color] = [Color("B9AE98"), Color("E8E0CF")]
const CRYSTAL: Array[Color] = [Color("2B8FB0"), Color("9FE7FF")]
const ICE: Array[Color] = [Color("7FB3D6"), Color("CFEFFF")]
const EYE := Color("7FF3FF")
const EYE_RAGE := Color("FF4A3D")
const BROW := Color("14202B")
const WOOD: Array[Color] = [Color("3B2A1E"), Color("6B4A32"), Color("8A5A34")]
const RUNNER: Array[Color] = [Color("7A848D"), Color("B9C3CC")]
const BRASS := Color("B8862E")
const LENS := Color("E8F6FF")
const SWIRL := Color("2A3D52")
const HOOD := Color("4B3A7A")
const PAGE := Color("F2EAD9")
const BOOK := Color("5B3FD0")
## Entrance snow drift, snowball and rage steam.
const DRIFT: Array[Color] = [Color("A9C4D6"), Color("DCEBF4"), Color("F7FBFE")]
const SNOWBALL: Array[Color] = [Color("B5D3E6"), Color("E4F3FB")]
const STEAM := Color("F4F8FB")

## Fur outline jaggedness pattern (repeats round the blob).
const JAG := [0.0, 0.17, 0.02, 0.12, 0.0, 0.2, 0.03, 0.1, 0.0, 0.15, 0.04, 0.19]

## Visual scale of each kind relative to the basic snow monster.
const SCALE_SNOW: float = 1.0
const SCALE_BIG: float = 1.75
const SCALE_WIZARD: float = 1.2
const SCALE_MEGA: float = 3.4

## Everything is recorded into this shared batch and submitted as one mesh.
static var _PEN := MeshBatch2D.new()


## kind: &"snow", &"big", &"wizard", &"mega", &"sled".
## step: -1..1 walk swing. punch: 0..1 attack pose. time: running clock.
## rage: boss enraged (red eyes). crying: boss sitting down crying.
## fx: special-action state (all optional):
##   "emerge"   0..1  boss entrance (snow mound -> burst out -> roar)
##   "roll"     0..1  boss rolling its freezing snowball (lifted overhead at the end)
##   "throw"    0..1  boss throw follow-through
##   "sit"      0..1  boss sitting down and crying
##   "rage_age" s     seconds since the boss enraged
static func draw(canvas: CanvasItem, kind: StringName, facing: float, step: float, punch: float,
		time: float, flash: bool, rage: bool = false, crying: bool = false, fx: Dictionary = {}) -> void:
	var c := _PEN
	match kind:
		&"sled":
			_sled(c, facing, step, time, flash)
		&"big":
			_yeti(c, Vector2.ZERO, facing, SCALE_BIG, step, punch, flash, false)
			_club(c, facing, SCALE_BIG, punch, flash)
		&"wizard":
			_yeti(c, Vector2.ZERO, facing, SCALE_WIZARD, step, 0.0, flash, false)
			_wizard_gear(c, facing, SCALE_WIZARD, punch, time, flash)
		&"mega":
			var emerge: float = float(fx.get("emerge", 1.0))
			var roll: float = float(fx.get("roll", -1.0))
			var sit: float = float(fx.get("sit", -1.0))
			var rage_age: float = float(fx.get("rage_age", -1.0))
			if emerge < 1.0:
				_mega_entrance(c, facing, emerge, time, flash)
			elif crying and sit >= 0.0:
				_mega_crying(c, facing, SCALE_MEGA, sit, time, flash)
			elif roll >= 0.0:
				if rage and rage_age >= 0.0:
					_rage_under(c, facing, SCALE_MEGA, rage_age, time, flash)
				_mega_roll(c, facing, SCALE_MEGA, roll, time, flash, rage)
			else:
				if rage and rage_age >= 0.0:
					_rage_under(c, facing, SCALE_MEGA, rage_age, time, flash)
				var throw: float = float(fx.get("throw", 0.0))
				_mega(c, facing, SCALE_MEGA, step * (1.0 - throw), maxf(punch, throw), time, flash, rage, {"mouth": throw * 0.8})
			if rage and rage_age >= 0.0 and not flash and emerge >= 1.0:
				_rage_steam(c, facing, SCALE_MEGA, rage_age, time)
		_:
			_yeti_lite(c, Vector2.ZERO, facing, SCALE_SNOW, step, punch, flash)
	c.flush_to(canvas)


# ==========================================
# The yeti body (shared by every kind)
# ==========================================

## pose (optional): "fists" [left, right] fist positions (arms reach to them),
## "eyes" &"closed" (squeezed shut), "mouth" 0..1 open, "squash" body scale.
static func _yeti(c: Object, origin: Vector2, facing: float, s: float, step: float, punch: float, flash: bool, rage: bool, pose: Dictionary = {}) -> void:
	var scale: Vector2 = Vector2.ONE * s * (pose.get("squash", Vector2.ONE) as Vector2)
	var fists: Array = pose.get("fists", [])
	var body := _fur_blob(Vector2(-3, 0), Vector2(11, 13.5), 16, 0)
	# Shadow.
	c.draw_set_transform(origin + Palette.SHADOW_OFFSET * 0.7 * s, facing, scale)
	c.draw_colored_polygon(body, Palette.SHADOW_COLOR)
	c.draw_circle(Vector2(8, 0), 6.6, Palette.SHADOW_COLOR)
	c.draw_set_transform(origin, facing, scale)
	# Fur body: dark rim, base, lit top-left tuft.
	c.draw_colored_polygon(body, _tone(FUR[0], flash))
	c.draw_colored_polygon(_fur_blob(Vector2(-4, -1), Vector2(10, 12.5), 16, 0), _tone(FUR[1], flash))
	c.draw_colored_polygon(_fur_blob(Vector2(-6, -3), Vector2(6.5, 8), 12, 3), _tone(FUR[2], flash))
	# Long furry arms with big blue fists out front.
	for side in [-1.0, 1.0]:
		var fist: Vector2
		if fists.size() == 2:
			# Posed arm: a thick furry limb from the shoulder to the given fist.
			fist = fists[0 if side < 0.0 else 1]
			var shoulder := Vector2(-1, 10.5 * side)
			c.draw_circle(shoulder, 4.4, _tone(FUR[0], flash))
			c.draw_line(shoulder, fist, _tone(FUR[0], flash), 8.6)
			c.draw_line(shoulder.lerp(fist, 0.05), fist, _tone(FUR[1], flash), 6.6)
		else:
			var reach: float = 6.0 * punch + 1.6 * step * side
			c.draw_colored_polygon(_ellipse(Vector2(2 + reach * 0.4, 12 * side), Vector2(7, 4.6), 12), _tone(FUR[0], flash))
			c.draw_colored_polygon(_ellipse(Vector2(1.4 + reach * 0.4, 11.5 * side), Vector2(6, 3.8), 12), _tone(FUR[1], flash))
			fist = Vector2(8 + reach, 13.5 * side)
		c.draw_colored_polygon(_ellipse(fist, Vector2(4.4, 4.0), 12), _tone(SKIN[0], flash))
		c.draw_colored_polygon(_ellipse(fist + Vector2(-0.5, -0.5), Vector2(3.6, 3.2), 12), _tone(SKIN[1], flash))
		if not flash:
			c.draw_circle(fist + Vector2(-1.4, -1.3), 1.2, SKIN[2])
	# Ice crystals on the shoulders and back.
	# Small yetis get three short crystals so they read as fur, not spikes.
	var small := s < 1.3
	var spikes: Array = [Vector4(-9, -4, -2.9, 8), Vector4(-9, 4, 2.9, 8), Vector4(-12, 0, PI, 9)] if small else [Vector4(-6, -9, -2.4, 7), Vector4(-9, -4, -2.9, 8), Vector4(-9, 4, 2.9, 8), Vector4(-6, 9, 2.4, 7), Vector4(-12, 0, PI, 9)]
	var spike_len := 0.55 if small else 1.0
	for spike in spikes:
		var base := Vector2(spike.x, spike.y)
		var dir := Vector2.RIGHT.rotated(spike.z)
		var side := Vector2(-dir.y, dir.x) * (1.7 if small else 2.4)
		var tip: Vector2 = base + dir * spike.w * spike_len
		c.draw_colored_polygon(PackedVector2Array([base + side * 1.3, tip, base - side * 1.3]), _tone(CRYSTAL[0], flash))
		c.draw_colored_polygon(PackedVector2Array([base + side * 0.7, tip, base]), _tone(CRYSTAL[1], flash))
	# Head: fur crown, blue face.
	c.draw_circle(Vector2(7, 0), 6.6, _tone(FUR[0], flash))
	c.draw_colored_polygon(_ellipse(Vector2(9, 0), Vector2(4.6, 5.2), 14), _tone(SKIN[0], flash))
	c.draw_colored_polygon(_ellipse(Vector2(9.4, -0.4), Vector2(3.9, 4.5), 14), _tone(SKIN[1], flash))
	c.draw_colored_polygon(_fur_blob(Vector2(5, 0), Vector2(4.2, 6.2), 8, 5), _tone(FUR[2], flash))
	# Curled horns.
	for side in [-1.0, 1.0]:
		var horn := _bezier(Vector2(5, 5 * side), Vector2(3, 10 * side), Vector2(-1, 11 * side), 8)
		c.draw_polyline(horn, _tone(HORN[0], flash), 2.6)
		if not flash:
			c.draw_polyline(horn, HORN[1], 1.2)
	if flash:
		return
	# Glowing eyes (or squeezed shut), angry brows, an open mouth, two fangs.
	var eye := EYE_RAGE if rage else EYE
	var closed: bool = pose.get("eyes", &"") == &"closed"
	for side in [-1.0, 1.0]:
		if closed:
			c.draw_polyline(PackedVector2Array([Vector2(10.0, 1.0 * side), Vector2(11.6, 2.2 * side), Vector2(10.0, 3.4 * side)]), BROW, 0.9)
		else:
			c.draw_circle(Vector2(11, 2.1 * side), 2.2, Color(eye, 0.3))
			c.draw_circle(Vector2(11, 2.1 * side), 1.15, eye)
			c.draw_line(Vector2(9.6, 3.6 * side), Vector2(11.6, 1.0 * side), BROW, 1.1)
	var mouth: float = float(pose.get("mouth", 0.0))
	if mouth > 0.02:
		c.draw_colored_polygon(_ellipse(Vector2(12.9, 0), Vector2(0.9 + 1.1 * mouth, 1.1 + 1.9 * mouth), 12), Color("1A2633"))
		c.draw_colored_polygon(_ellipse(Vector2(13.3, 0), Vector2(0.4 + 0.5 * mouth, 0.5 + 1.0 * mouth), 10), Color("C9536A"))
	c.draw_colored_polygon(PackedVector2Array([Vector2(12.6, -1.3), Vector2(14.2, -0.6), Vector2(12.6, 0.0)]), Color.WHITE)
	c.draw_colored_polygon(PackedVector2Array([Vector2(12.6, 0.0), Vector2(14.2, 0.6), Vector2(12.6, 1.3)]), Color.WHITE)


## Cheap small yeti (the common Snow Monster and the sled riders, which can be
## on screen by the dozen): same silhouette and colours, far fewer polygons,
## no ice crystals.
static func _yeti_lite(c: Object, origin: Vector2, facing: float, s: float, step: float, punch: float, flash: bool) -> void:
	var body := _fur_blob(Vector2(-3, 0), Vector2(11, 13.5), 9, 0)
	c.draw_set_transform(origin + Palette.SHADOW_OFFSET * 0.7 * s, facing, Vector2.ONE * s)
	c.draw_colored_polygon(body, Palette.SHADOW_COLOR)
	c.draw_set_transform(origin, facing, Vector2.ONE * s)
	c.draw_colored_polygon(body, _tone(FUR[0], flash))
	c.draw_colored_polygon(_fur_blob(Vector2(-4, -1), Vector2(10, 12.5), 9, 0), _tone(FUR[1], flash))
	c.draw_colored_polygon(_ellipse(Vector2(-6, -3), Vector2(5.5, 6.5), 8), _tone(FUR[2], flash))
	for side in [-1.0, 1.0]:
		var reach: float = 6.0 * punch + 1.6 * step * side
		c.draw_colored_polygon(_ellipse(Vector2(2 + reach * 0.4, 12 * side), Vector2(7, 4.6), 8), _tone(FUR[0], flash))
		c.draw_colored_polygon(_ellipse(Vector2(8 + reach, 13.5 * side), Vector2(4.2, 3.8), 8), _tone(SKIN[1], flash))
	c.draw_colored_polygon(_ellipse(Vector2(7, 0), Vector2(6.6, 6.6), 10), _tone(FUR[0], flash))
	c.draw_colored_polygon(_ellipse(Vector2(9.2, -0.2), Vector2(4.3, 4.9), 10), _tone(SKIN[1], flash))
	for side in [-1.0, 1.0]:
		c.draw_line(Vector2(5, 5 * side), Vector2(1.5, 10 * side), _tone(HORN[0], flash), 2.4)
	if flash:
		return
	for side in [-1.0, 1.0]:
		c.draw_colored_polygon(_ellipse(Vector2(11, 2.1 * side), Vector2(1.2, 1.2), 6), EYE)
		c.draw_line(Vector2(9.6, 3.6 * side), Vector2(11.6, 1.0 * side), BROW, 1.1)


# ==========================================
# Kind-specific parts
# ==========================================

## Big Snow Monster's ice club in its right fist; swings forward on attack.
static func _club(c: Object, facing: float, s: float, punch: float, flash: bool) -> void:
	c.draw_set_transform(Vector2.ZERO, facing, Vector2.ONE * s)
	var hand := Vector2(8 + 6.0 * punch, 13.5)
	var angle := deg_to_rad(-20.0 - 50.0 * punch)
	var dir := Vector2.RIGHT.rotated(angle)
	var side := Vector2(-dir.y, dir.x)
	c.draw_line(hand - dir * 2.0, hand + dir * 12.0, _tone(WOOD[1], flash), 3.4)
	var head := hand + dir * 16.0
	var block := PackedVector2Array([head - dir * 5 - side * 5, head + dir * 4 - side * 5, head + dir * 7, head + dir * 4 + side * 5, head - dir * 5 + side * 5, head - dir * 7])
	c.draw_colored_polygon(block, _tone(ICE[0], flash))
	c.draw_colored_polygon(_shrink(block, 0.72), _tone(ICE[1], flash))


## Wizard: hood, swirly nerd goggles, spell book and ice staff. punch here is
## the cast: the staff crystal flares.
static func _wizard_gear(c: Object, facing: float, s: float, cast: float, time: float, flash: bool) -> void:
	c.draw_set_transform(Vector2.ZERO, facing, Vector2.ONE * s)
	# Hood over the back of the head.
	c.draw_polyline(_bezier(Vector2(3, -6.5), Vector2(-4, 0), Vector2(3, 6.5), 10), _tone(HOOD, flash), 3.2)
	# Thick round goggles with brass rims and swirl lenses.
	for side in [-1.0, 1.0]:
		var lens := Vector2(11.2, 2.7 * side)
		c.draw_circle(lens, 3.5, _tone(BRASS, flash))
		c.draw_circle(lens, 2.8, _tone(LENS, flash))
		if not flash:
			var spiral := PackedVector2Array()
			for k in range(14):
				var a: float = float(k) * 0.75 + time * 5.0 * side
				spiral.append(lens + Vector2(cos(a), sin(a)) * (0.25 + 0.17 * float(k)))
			c.draw_polyline(spiral, SWIRL, 0.6)
	c.draw_line(Vector2(11.2, -0.8), Vector2(11.2, 0.8), _tone(BRASS, flash), 1.4)
	# Open spell book held out in the left fist.
	var book := Vector2(12, -15)
	c.draw_colored_polygon(PackedVector2Array([book + Vector2(-6, -4), book + Vector2(0, -3), book + Vector2(0, 4), book + Vector2(-6, 3)]), _tone(BOOK, flash))
	c.draw_colored_polygon(PackedVector2Array([book + Vector2(0, -3), book + Vector2(6, -4), book + Vector2(6, 3), book + Vector2(0, 4)]), _tone(BOOK, flash))
	c.draw_colored_polygon(PackedVector2Array([book + Vector2(-5.2, -3.1), book + Vector2(-0.4, -2.4), book + Vector2(-0.4, 3.2), book + Vector2(-5.2, 2.3)]), _tone(PAGE, flash))
	c.draw_colored_polygon(PackedVector2Array([book + Vector2(0.4, -2.4), book + Vector2(5.2, -3.1), book + Vector2(5.2, 2.3), book + Vector2(0.4, 3.2)]), _tone(Color.WHITE, flash))
	if not flash:
		for row in [-1.0, 0.6]:
			c.draw_line(book + Vector2(-4.4, row), book + Vector2(-1.4, row + 0.3), ICE[0], 0.6)
			c.draw_line(book + Vector2(1.4, row + 0.3), book + Vector2(4.4, row), ICE[0], 0.6)
	# Staff with a glowing ice crystal in the right fist.
	c.draw_line(Vector2(-6, 15), Vector2(20, 13), _tone(WOOD[1], flash), 2.0)
	var crystal := Vector2(22, 13)
	if not flash:
		var glow := 5.0 + 1.5 * sin(time * 4.0) + 6.0 * cast
		c.draw_circle(crystal, glow, Color(CRYSTAL[1], 0.22 + 0.25 * cast))
	c.draw_colored_polygon(PackedVector2Array([crystal + Vector2(0, -4.5), crystal + Vector2(3, 0), crystal + Vector2(0, 4.5), crystal + Vector2(-3, 0)]), _tone(CRYSTAL[0], flash))
	c.draw_colored_polygon(PackedVector2Array([crystal + Vector2(0, -3.6), crystal + Vector2(2.2, 0), crystal + Vector2(0, 0.6), crystal + Vector2(-2.2, 0)]), _tone(ICE[1], flash))


## Boss: ice boulder on its back and a frost aura (drawn under the body).
static func _mega_back(c: Object, facing: float, s: float, time: float, flash: bool) -> void:
	c.draw_set_transform(Vector2.ZERO, facing, Vector2.ONE * s)
	if not flash:
		var r := 20.0 + 1.5 * sin(time * 2.6)
		for k in range(16):
			var a := TAU * float(k) / 16.0 + time * 0.4
			c.draw_arc(Vector2(-2, 0), r, a, a + 0.22, 4, Color(Color("DFF6FF"), 0.55), 0.9)
	var boulder := PackedVector2Array([Vector2(-12, -6), Vector2(-19, -9), Vector2(-24, 0), Vector2(-19, 8), Vector2(-12, 6)])
	c.draw_colored_polygon(Palette.offset_points(boulder, Palette.SHADOW_OFFSET * 0.2), Palette.SHADOW_COLOR)
	c.draw_colored_polygon(boulder, _tone(ICE[0], flash))
	c.draw_colored_polygon(_shrink(boulder, 0.7), _tone(ICE[1], flash))


## Boss: ice crown on the back of the head and big ram horns.
static func _mega_crown(c: Object, facing: float, s: float, flash: bool) -> void:
	c.draw_set_transform(Vector2.ZERO, facing, Vector2.ONE * s)
	for side in [-1.0, 1.0]:
		var horn := _bezier(Vector2(4, 6 * side), Vector2(-2, 15 * side), Vector2(-8, 11 * side), 10)
		horn.append_array(_bezier(Vector2(-8, 11 * side), Vector2(-11, 8 * side), Vector2(-8, 6 * side), 5))
		c.draw_polyline(horn, _tone(HORN[0], flash), 3.4)
		if not flash:
			c.draw_polyline(horn, HORN[1], 1.6)
	for a in [-0.9, -0.45, 0.0, 0.45, 0.9]:
		var base := Vector2(1.0 - 2.5 * cos(a), 5.5 * sin(a))
		var tip := base + Vector2(-5.5 * cos(a), 4.5 * sin(a))
		c.draw_colored_polygon(PackedVector2Array([base + Vector2(1.0, -1.6), tip, base + Vector2(1.0, 1.6)]), _tone(ICE[1], flash))


## Wooden sled with four riders at full size.
static func _sled(c: Object, facing: float, step: float, time: float, flash: bool) -> void:
	var deck := PackedVector2Array([Vector2(-34, -28), Vector2(30, -28), Vector2(38, -20), Vector2(38, 20), Vector2(30, 28), Vector2(-34, 28)])
	c.draw_set_transform(Palette.SHADOW_OFFSET * 0.7, facing, Vector2.ONE)
	c.draw_colored_polygon(deck, Palette.SHADOW_COLOR)
	c.draw_set_transform(Vector2.ZERO, facing, Vector2.ONE)
	# Runners curl up at the front.
	for side in [-1.0, 1.0]:
		var runner := PackedVector2Array([Vector2(-40, 31 * side), Vector2(30, 31 * side)])
		runner.append_array(_bezier(Vector2(30, 31 * side), Vector2(44, 31 * side), Vector2(44, 21 * side), 6))
		c.draw_polyline(runner, _tone(RUNNER[0], flash), 4.0)
		if not flash:
			c.draw_polyline(runner, RUNNER[1], 1.8)
	c.draw_colored_polygon(deck, _tone(WOOD[0], flash))
	c.draw_colored_polygon(_shrink(deck, 0.92), _tone(WOOD[2], flash))
	if not flash:
		for y in [-14.0, 0.0, 14.0]:
			c.draw_line(Vector2(-31, y), Vector2(35, y), WOOD[1], 1.4)
	# Tow rope and a little red pennant at the back.
	c.draw_line(Vector2(42, 0), Vector2(52, -3), _tone(Color("C8B48C"), flash), 1.6)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-34, -20), Vector2(-46, -26), Vector2(-42, -16)]), _tone(Color("D9534F"), flash))
	# Four riders, same size as the snow monsters on foot.
	var bob := sin(time * 9.0) * 0.6
	for seat in [Vector2(-16, -14), Vector2(-16, 14), Vector2(14, -14), Vector2(14, 14)]:
		var local: Vector2 = seat + Vector2(bob, 0)
		_yeti_lite(c, local.rotated(facing), facing, 0.95, step * 0.3, 0.0, flash)


# ==========================================
# Special actions
# ==========================================

## Boss body: back boulder, the yeti, then crown and horns.
static func _mega(c: Object, facing: float, s: float, step: float, punch: float, time: float, flash: bool, rage: bool, pose: Dictionary = {}) -> void:
	_mega_back(c, facing, s, time, flash)
	_yeti(c, Vector2.ZERO, facing, s, step, punch, flash, rage, pose)
	_mega_crown(c, facing, s, flash)


## Boss entrance, e 0..1 over the entrance time:
## 0-0.62 a snow mound shakes and swells, cracking, glowing eyes inside;
## 0.62-0.8 it bursts, chunks fly out and the boss rises up;
## 0.8-1 the boss roars (open mouth, rings blasting forward).
static func _mega_entrance(c: Object, facing: float, e: float, time: float, flash: bool) -> void:
	var s := SCALE_MEGA
	c.draw_set_transform(Vector2.ZERO, facing, Vector2.ONE * s)
	if e < 0.62:
		var g := e / 0.62
		var shake := Vector2(sin(time * 47.0), cos(time * 39.0)) * (0.25 + 0.75 * g)
		var r := lerpf(8.0, 15.0, 1.0 - pow(1.0 - g, 2.0))
		var mound := _drift(shake, r, 0.0)
		c.draw_colored_polygon(Palette.offset_points(mound, Palette.SHADOW_OFFSET * 0.25), Palette.SHADOW_COLOR)
		c.draw_colored_polygon(mound, DRIFT[0])
		c.draw_colored_polygon(_drift(shake + Vector2(-0.8, -0.8), r * 0.86, 1.3), DRIFT[1])
		c.draw_colored_polygon(_drift(shake + Vector2(-r * 0.3, -r * 0.3), r * 0.42, 2.1), DRIFT[2])
		if flash:
			return
		# Cracks spread as it swells.
		for index in range(6):
			if g < 0.15 + float(index) * 0.13:
				continue
			var dir := Vector2.RIGHT.rotated(float(index) * 1.05 + 0.3)
			var perp := Vector2(-dir.y, dir.x)
			c.draw_polyline(PackedVector2Array([shake + dir * 2.0, shake + dir * r * 0.5 + perp * 1.4, shake + dir * r * 0.92 - perp * 0.6]), ICE[0], 0.7)
		# Glowing eyes inside.
		if g > 0.4:
			var blink := 1.0 if fposmod(time, 1.6) > 0.12 else 0.0
			var a := smoothstep(0.4, 0.7, g) * blink
			for side in [-1.0, 1.0]:
				c.draw_circle(shake + Vector2(5, 2.4 * side), 1.9, Color(EYE, 0.35 * a))
				c.draw_circle(shake + Vector2(5, 2.4 * side), 0.9, Color(EYE, a))
		# Snow spraying off the edges.
		for index in range(12):
			var ph := fposmod(time * 1.8 + float(index) * 0.083, 1.0)
			var dir := Vector2.RIGHT.rotated(float(index) * 2.39)
			c.draw_circle(shake + dir * (r + ph * 9.0), 0.9 * (1.0 - ph) + 0.2, Color(1, 1, 1, (1.0 - ph) * (0.3 + 0.7 * g)))
		return
	var t := clampf((e - 0.62) / 0.18, 0.0, 1.0)
	var out := 1.0 - pow(1.0 - t, 3.0)
	# Snow cloud and flying mound chunks.
	if t < 1.0 and not flash:
		for index in range(8):
			var a := TAU * float(index) / 8.0 + 0.3
			c.draw_circle(Vector2(cos(a), sin(a)) * (8.0 + 16.0 * out), 5.0 + 4.0 * out, Color(DRIFT[2], 0.55 * (1.0 - t)))
	var rise := lerpf(0.55, 1.0, _back_out(t))
	var roar := smoothstep(0.8, 0.86, e) * (1.0 - smoothstep(0.96, 1.0, e))
	_mega(c, facing, s * rise, 0.0, roar * 0.4, time, flash, false, {"mouth": roar})
	c.draw_set_transform(Vector2.ZERO, facing, Vector2.ONE * s)
	if t < 1.0:
		for index in range(10):
			var a := TAU * float(index) / 10.0 + 0.15
			var p := Vector2(cos(a), sin(a)) * (12.0 + 24.0 * out)
			var size := 3.6 * (1.0 - 0.5 * t)
			var tone: Color = DRIFT[1] if index % 2 == 0 else DRIFT[0]
			c.draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(5, size, float(index) + t * 6.0), p), Color(_tone(tone, flash), 1.0 - t * t))
	if roar > 0.0 and not flash:
		for ring in range(3):
			var ph := fposmod(time * 1.7 + float(ring) / 3.0, 1.0)
			var radius := 16.0 + 22.0 * ph
			c.draw_arc(Vector2(6, 0), radius, -0.75, 0.75, 14, Color(1, 1, 1, roar * (1.0 - ph) * 0.85), 1.4 * (1.0 - ph) + 0.3)


## Boss rolling the freezing snowball, k 0..1 over the wind-up:
## 0-0.8 both fists roll a growing snowball in front, snow swirling into it;
## 0.8-1 it is hoisted overhead (bigger, higher shadow) ready to throw.
static func _mega_roll(c: Object, facing: float, s: float, k: float, time: float, flash: bool, rage: bool = false) -> void:
	var lift := smoothstep(0.8, 1.0, k)
	var grow := 1.0 - pow(1.0 - clampf(k / 0.8, 0.0, 1.0), 2.0)
	var ball_r := lerpf(1.6, 6.0, grow)
	var ball := Vector2(12.5 + ball_r, 0.0).lerp(Vector2(-2.0, 0.0), lift)
	var radius := ball_r * (1.0 + 0.3 * lift)
	var fists := []
	for side in [-1.0, 1.0]:
		var wob := Vector2(cos(time * 7.0 + side * 1.57) * 1.3, sin(time * 7.0 + side * 1.57) * 0.9) * (1.0 - lift)
		fists.append(ball + Vector2(-1.0, side * (radius + 2.4)) + wob)
	_mega(c, facing, s, 0.0, 0.0, time, flash, rage, {"fists": fists, "mouth": 0.25 + 0.5 * lift})
	c.draw_set_transform(Vector2.ZERO, facing, Vector2.ONE * s)
	if flash:
		c.draw_circle(ball, radius, Palette.HIT_FLASH)
		return
	# Charge glow in the last stretch.
	if k > 0.55:
		var pulse := 0.5 + 0.5 * sin(time * 12.0)
		c.draw_circle(ball, radius * (1.45 + 0.12 * pulse), Color(CRYSTAL[1], 0.18 + 0.2 * smoothstep(0.55, 1.0, k)))
	# Hoisted: shadow drops away under it.
	if lift > 0.0:
		c.draw_circle(ball + Vector2(3.0, 3.0) * lift, radius, Color(Palette.SHADOW_COLOR, Palette.SHADOW_COLOR.a * lift))
	_snowball(c, ball, radius, time * 3.0 * (1.0 - lift) + 1.0)
	# Snow swirling in.
	for index in range(9):
		var ph := fposmod(time * 1.3 + float(index) * 0.111, 1.0)
		var a := float(index) * 2.4 + time * 3.0 + ph * 2.0
		c.draw_circle(ball + Vector2(cos(a), sin(a)) * (radius + 9.0 * (1.0 - ph)), 0.7, Color(1, 1, 1, ph * 0.9))


## A packed snowball with ice bits, rotating with `spin`.
static func _snowball(c: Object, at: Vector2, radius: float, spin: float) -> void:
	c.draw_circle(at, radius, SNOWBALL[0])
	c.draw_circle(at + Vector2(-0.12, -0.12) * radius, radius * 0.86, SNOWBALL[1])
	c.draw_arc(at, radius * 0.62, spin, spin + 2.2, 8, SNOWBALL[0], maxf(radius * 0.08, 0.3))
	for index in range(3):
		var a := spin + TAU * float(index) / 3.0
		var p := at + Vector2(cos(a), sin(a)) * radius * 0.55
		var d := radius * 0.16
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -d), p + Vector2(d * 0.7, 0), p + Vector2(0, d), p + Vector2(-d * 0.7, 0)]), CRYSTAL[1])
	c.draw_circle(at + Vector2(-0.38, -0.38) * radius, radius * 0.24, Color.WHITE)


## Mega Monster sitting on the ground crying when it is the last one left
## (p 0..1 over the cry): legs out front, fists rubbing its eyes, wailing
## mouth, sobbing body and tears spraying into a growing puddle.
static func _mega_crying(c: Object, facing: float, s: float, p: float, time: float, flash: bool) -> void:
	var sink := smoothstep(0.0, 0.12, p)
	c.draw_set_transform(Vector2.ZERO, facing, Vector2.ONE * s)
	if not flash:
		var pr := lerpf(6.0, 22.0, smoothstep(0.05, 1.0, p))
		c.draw_colored_polygon(_ellipse(Vector2(1, 0), Vector2(pr * 1.1, pr), 22), Color(Palette.COBALT, 0.32))
		c.draw_colored_polygon(_ellipse(Vector2(-1, -2), Vector2(pr * 0.7, pr * 0.6), 18), Color(Palette.COBALT_LIGHT, 0.18))
		var ripple := fposmod(time * 0.9, 1.0)
		c.draw_arc(Vector2(-1, 0), pr * ripple, 0.0, TAU, 22, Color(Palette.COBALT_LIGHT, 0.4 * (1.0 - ripple)), 0.6)
	# Legs stretched out in front, big blue soles.
	for side in [-1.0, 1.0]:
		var leg := Vector2(lerpf(4.0, 15.0, sink), 9.0 * side)
		c.draw_colored_polygon(_ellipse(leg, Vector2(6.0, 4.2), 12), _tone(FUR[0], flash))
		c.draw_colored_polygon(_ellipse(leg + Vector2(-0.4, -0.4), Vector2(5.0, 3.4), 12), _tone(FUR[1], flash))
		var sole := leg + Vector2(5.2, 0.0)
		c.draw_colored_polygon(_ellipse(sole, Vector2(2.2, 3.4), 12), _tone(SKIN[0], flash))
		c.draw_colored_polygon(_ellipse(sole + Vector2(0.3, 0), Vector2(1.5, 2.6), 10), _tone(SKIN[1], flash))
	_mega_back(c, facing, s, time, flash)
	var sob := sin(time * 13.0)
	var squash := Vector2(1.0 - 0.06 * sink + 0.03 * sob, 1.0 + 0.05 * sink - 0.02 * sob)
	var rub := sin(time * 9.0)
	var fists := [Vector2(10.6 + rub * 0.8, -6.6), Vector2(10.6 - rub * 0.8, 6.6)]
	_yeti(c, Vector2.ZERO, facing, s, 0.0, 0.0, flash, false, {"fists": fists, "eyes": &"closed", "mouth": 0.55 + 0.45 * absf(sob), "squash": squash})
	_mega_crown(c, facing, s, flash)
	if flash:
		return
	# Tears gushing out sideways from under the fists.
	c.draw_set_transform(Vector2.ZERO, facing, Vector2.ONE * s)
	for side in [-1.0, 1.0]:
		var start := Vector2(12.0, 3.0 * side)
		for index in range(9):
			var ph := fposmod(time * 1.6 + float(index) / 9.0 + (0.05 if side > 0.0 else 0.0), 1.0)
			var at := start + Vector2(7.0 * sin(ph * PI) - 9.0 * ph, side * (3.0 + 20.0 * ph))
			c.draw_circle(at, lerpf(1.9, 1.0, ph), Color(Palette.COBALT, 1.0 - 0.5 * ph))
			c.draw_circle(at + Vector2(-0.4, -0.4), lerpf(0.9, 0.4, ph), Color(Palette.COBALT_LIGHT, 1.0 - 0.5 * ph))


## Enraged boss: a pulsing red glow underneath, and a red shockwave
## the moment it gets up.
static func _rage_under(c: Object, facing: float, s: float, age: float, time: float, flash: bool) -> void:
	if flash:
		return
	c.draw_set_transform(Vector2.ZERO, facing, Vector2.ONE * s)
	var pulse := 0.5 + 0.5 * sin(time * 6.0)
	c.draw_circle(Vector2(-2, 0), 17.5 + pulse, Color(EYE_RAGE, 0.17 + 0.1 * pulse))
	if age < 0.7:
		var t := age / 0.7
		var out := 1.0 - pow(1.0 - t, 3.0)
		c.draw_arc(Vector2(-2, 0), lerpf(12.0, 38.0, out), 0.0, TAU, 40, Color(EYE_RAGE, 0.85 * (1.0 - t)), lerpf(3.0, 0.5, t))


## Enraged boss: steam puffing off its head (a burst when it gets up).
static func _rage_steam(c: Object, facing: float, s: float, age: float, time: float) -> void:
	c.draw_set_transform(Vector2.ZERO, facing, Vector2.ONE * s)
	for side in [-1.0, 1.0]:
		for index in range(2):
			var ph := fposmod(time * 1.5 + float(index) * 0.5 + (0.25 if side > 0.0 else 0.0), 1.0)
			c.draw_circle(Vector2(4.0 - ph * 9.0, side * (7.0 + ph * 5.0)), lerpf(1.4, 4.2, ph), Color(STEAM, 0.85 * (1.0 - ph)))
	if age < 0.7:
		var t := age / 0.7
		for index in range(8):
			var a := TAU * float(index) / 8.0
			c.draw_circle(Vector2(6, 0) + Vector2(cos(a), sin(a)) * (6.0 + 14.0 * t), 2.0 + 3.0 * t, Color(STEAM, 0.75 * (1.0 - t)))


## Rounded, lumpy snow drift outline.
static func _drift(center: Vector2, radius: float, seed: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(24):
		var a := TAU * float(index) / 24.0
		var r := radius * (1.0 + 0.07 * sin(a * 3.0 + seed) + 0.04 * sin(a * 5.0 + seed * 2.0))
		points.append(center + Vector2(cos(a), sin(a)) * r)
	return points


static func _back_out(t: float) -> float:
	var k := 1.7
	var u := t - 1.0
	return 1.0 + (k + 1.0) * u * u * u + k * u * u


# ==========================================
# Helpers
# ==========================================

static func _tone(color: Color, flash: bool) -> Color:
	return Palette.HIT_FLASH if flash else color


## Shaggy outline: points alternate between full radius and a jagged inner one.
## Unit shapes are built once and cached; each call is one transform.
static var _UNIT_BLOBS: Dictionary = {}
static var _UNIT_ELLIPSES: Dictionary = {}

static func _fur_blob(center: Vector2, radius: Vector2, tufts: int, seed_offset: int) -> PackedVector2Array:
	var key := tufts * 1000 + seed_offset
	var unit: PackedVector2Array = _UNIT_BLOBS.get(key, PackedVector2Array())
	if unit.is_empty():
		for index in range(tufts * 2):
			var a := PI * float(index) / float(tufts)
			var r: float = 1.0 if index % 2 == 0 else 1.0 - 0.12 - float(JAG[(index + seed_offset) % JAG.size()])
			unit.append(Vector2(cos(a), sin(a)) * r)
		_UNIT_BLOBS[key] = unit
	return Transform2D(0.0, radius, 0.0, center) * unit


static func _ellipse(center: Vector2, radius: Vector2, sides: int) -> PackedVector2Array:
	var unit: PackedVector2Array = _UNIT_ELLIPSES.get(sides, PackedVector2Array())
	if unit.is_empty():
		for index in range(sides):
			var a := TAU * float(index) / float(sides)
			unit.append(Vector2(cos(a), sin(a)))
		_UNIT_ELLIPSES[sides] = unit
	return Transform2D(0.0, radius, 0.0, center) * unit


static func _bezier(a: Vector2, control: Vector2, b: Vector2, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(steps + 1):
		var t := float(index) / float(steps)
		points.append(a.lerp(control, t).lerp(control.lerp(b, t), t))
	return points


static func _shrink(points: PackedVector2Array, factor: float) -> PackedVector2Array:
	var center := Vector2.ZERO
	for point in points:
		center += point
	center /= float(points.size())
	var result := PackedVector2Array()
	for point in points:
		result.append(center + (point - center) * factor)
	return result
