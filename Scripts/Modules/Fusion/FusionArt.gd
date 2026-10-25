class_name FusionArt
extends RefCounted

## Fusion weapon art (user picks from the design canvas, 2026-10-24). Bigger
## than the base weapons: an armoured octagon base split by a glowing fusion
## seam in the element colour, longer barrels reaching out of the cell.
## Turrets face local +x; `sh` is the local-space shadow offset (the shadow
## stays world down-right while the turret turns). Presentation only.

const MECH := Color("3B3530")
const MECH_L := Color("5A524B")
const MECH_D := Color("2A2522")
const STEEL := Color("8E949A")
const STEEL_L := Color("C9CED3")
const STEEL_D := Color("6E747A")
const BONE := Color("E8E1D3")
const PART := Color("CFC5B2")
const PART_E := Color("B3A893")
const ACC := Color("F08A24")
const SHOT := Color("FFC061")
const CORE := Color("FFF2C2")
const BRASS := Color("C9963A")
const VIO := Color("B69CFF")
const VIO_D := Color("5B3FD0")
const VIO_L := Color("EEE6FF")
const VOID := Color("120E1C")
const FIRE := Color("F06A24")
const FIRE_D := Color("A8261C")
const FIRE_L := Color("FFC861")
const RED_TANK := Color("C8352B")
const RED_TANK_D := Color("7A1A1C")
const SHADOW := Color(0, 0, 0, 0.28)


static func element_color(weapon_id: StringName) -> Color:
	match weapon_id:
		&"knockback_machine_gun", &"knockback_cannon", &"knockback_laser":
			return VIO
		&"laser_machine_gun", &"heavy_laser", &"laser_chainsaw":
			return SHOT
		&"flame_machine_gun", &"flame_cannon", &"flame_laser":
			return FIRE
	return ACC


static func base_radius(weapon_id: StringName) -> float:
	match weapon_id:
		&"siege_cannon", &"heavy_laser", &"knockback_cannon", &"flame_cannon", &"laser_chainsaw":
			return 29.5
	return 28.0


## Where the projectile / beam leaves the turret (local +x distance).
static func muzzle_x(weapon_id: StringName) -> float:
	match weapon_id:
		&"scatter_machine_gun": return 48.0
		&"knockback_machine_gun": return 47.0
		&"laser_machine_gun": return 56.0
		&"sawblade_machine_gun": return 48.0
		&"flame_machine_gun": return 49.0
		&"laser_chainsaw": return 26.0
		&"heavy_laser": return 50.0
		&"automatic_cannon": return 52.0
		&"siege_cannon": return 22.0
		&"knockback_cannon": return 54.0
		&"flame_cannon": return 54.0
		&"knockback_laser": return 41.0
		&"flame_laser": return 50.0
	return 30.0


# ------------------------------------------------------------ primitives

static func ngon(c: Vector2, r: float, n: int, rot: float = 0.0) -> PackedVector2Array:
	var p := PackedVector2Array()
	for k in range(n):
		var a := rot + TAU * float(k) / float(n)
		p.append(c + Vector2(cos(a), sin(a)) * r)
	return p


static func _quad(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


static func rect(ci: CanvasItem, r: Rect2, col: Color) -> void:
	ci.draw_colored_polygon(_quad(r), col)


static func rr(ci: CanvasItem, r: Rect2, rad: float, col: Color) -> void:
	ci.draw_colored_polygon(Palette.rounded_rect_points(r, rad), col)


static func barrel(ci: CanvasItem, sh: Vector2, x0: float, x1: float, y: float, h: float, body: Color = MECH, hi: Color = MECH_L) -> void:
	rect(ci, Rect2(Vector2(x0, y - h) + sh, Vector2(x1 - x0, h * 2.0)), SHADOW)
	rect(ci, Rect2(x0, y - h, x1 - x0, h * 2.0), body)
	rect(ci, Rect2(x0, y - h, x1 - x0, h * 0.7), hi)


static func muzzle(ci: CanvasItem, x: float, y: float, h: float, col: Color = ACC, w: float = 4.0) -> void:
	rect(ci, Rect2(x - w, y - h - 1.0, w, h * 2.0 + 2.0), col)


static func rivets(ci: CanvasItem, pts: Array) -> void:
	for p in pts:
		ci.draw_circle(p, 1.3, MECH_D)
		ci.draw_circle((p as Vector2) + Vector2(-0.3, -0.3), 0.6, MECH_L)


static func glow(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c, r * 1.9, Color(col, 0.12))
	ci.draw_circle(c, r * 1.35, Color(col, 0.22))
	ci.draw_circle(c, r, col)


static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, ang: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for k in range(33):
		var t := TAU * float(k) / 32.0
		pts.append(c + Vector2(cos(t) * rx, sin(t) * ry).rotated(ang))
	ci.draw_polyline(pts, col, w)


static func saw_blade(ci: CanvasItem, c: Vector2, r: float, rot: float, sh: Vector2 = Vector2(2, 3)) -> void:
	var teeth := PackedVector2Array()
	var shade := PackedVector2Array()
	for k in range(24):
		var a := rot + TAU * float(k) / 24.0
		var p := c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.8)
		teeth.append(p)
		shade.append(p + sh)
	ci.draw_colored_polygon(shade, SHADOW)
	ci.draw_colored_polygon(teeth, STEEL_L)
	ci.draw_circle(c, r * 0.68, STEEL)
	ci.draw_line(c - Vector2(r * 0.5, 0).rotated(rot), c + Vector2(r * 0.5, 0).rotated(rot), STEEL_D, r * 0.14)
	ci.draw_line(c - Vector2(0, r * 0.5).rotated(rot), c + Vector2(0, r * 0.5).rotated(rot), STEEL_D, r * 0.14)
	ci.draw_circle(c, r * 0.22, MECH)
	ci.draw_circle(c + Vector2(-0.6, -0.6), r * 0.1, ACC)


static func flame_puff(ci: CanvasItem, p: Vector2, r: float) -> void:
	ci.draw_circle(p, r * 1.4, Color(FIRE, 0.25))
	ci.draw_circle(p, r, FIRE)
	ci.draw_circle(p + Vector2(-r * 0.2, -r * 0.2), r * 0.6, FIRE_L)


# ------------------------------------------------------------ base (static, on the weapon node)

static func draw_base(ci: CanvasItem, weapon_id: StringName, sh: Vector2) -> void:
	var r := base_radius(weapon_id)
	var seam := element_color(weapon_id)
	ci.draw_colored_polygon(ngon(sh, r, 8, PI / 8.0), SHADOW)
	ci.draw_colored_polygon(ngon(Vector2.ZERO, r, 8, PI / 8.0), PART_E)
	ci.draw_colored_polygon(ngon(Vector2(-0.8, -0.8), r - 2.2, 8, PI / 8.0), PART)
	ci.draw_colored_polygon(ngon(Vector2(-0.8, -0.8), r - 6.5, 8, PI / 8.0), BONE)
	ci.draw_line(Vector2(-r, -r) * 0.7, Vector2(r, r) * 0.7, Color(seam, 0.35), 3.2)
	ci.draw_line(Vector2(-r, -r) * 0.7, Vector2(r, r) * 0.7, seam, 1.2)
	rivets(ci, [Vector2(-r * 0.8, 0), Vector2(0, -r * 0.8), Vector2(0, r * 0.8), Vector2(r * 0.8, 0), Vector2(-r * 0.56, r * 0.56), Vector2(r * 0.56, -r * 0.56)])


# ------------------------------------------------------------ turrets (rotating, on the Turret node)

## t: animation clock; firing: 0..1 recent-fire flash; extra: weapon-specific
## (flame laser: ramp 0..1).
static func draw_turret(ci: CanvasItem, weapon_id: StringName, sh: Vector2, t: float, firing: float, extra: float = 0.0) -> void:
	match weapon_id:
		&"scatter_machine_gun": _scatter(ci, sh, t, firing)
		&"knockback_machine_gun": _knockback_mg(ci, sh, t, firing)
		&"laser_machine_gun": _laser_mg(ci, sh, t, firing)
		&"sawblade_machine_gun": _sawblade_mg(ci, sh, t, firing)
		&"flame_machine_gun": _flame_mg(ci, sh, t, firing)
		&"laser_chainsaw": _laser_chainsaw(ci, sh, t, firing)
		&"heavy_laser": _heavy_laser(ci, sh, t, firing)
		&"automatic_cannon": _auto_cannon(ci, sh, t, firing)
		&"siege_cannon": _siege_cannon(ci, sh, t, firing)
		&"knockback_cannon": _knockback_cannon(ci, sh, t, firing)
		&"flame_cannon": _flame_cannon(ci, sh, t, firing)
		&"knockback_laser": _knockback_laser(ci, sh, t, firing)
		&"flame_laser": _flame_laser(ci, sh, t, firing, extra)
		_:
			barrel(ci, sh, 4, 30, 0, 4)


## Scatter MG (A, bigger muzzles + detail): five fanned barrels with flared
## orange muzzles, heat bands, a receiver with vents and a side ammo drum.
static func _scatter(ci: CanvasItem, sh: Vector2, t: float, firing: float) -> void:
	for k in range(5):
		var a := (float(k) - 2.0) * 0.2
		var dir := Vector2.RIGHT.rotated(a)
		var side := dir.orthogonal() * 2.6
		var p0 := Vector2(6, 0)
		var tip := dir * 44.0
		ci.draw_colored_polygon(PackedVector2Array([p0 + side + sh, tip + side + sh, tip - side + sh, p0 - side + sh]), SHADOW)
		ci.draw_colored_polygon(PackedVector2Array([p0 + side, tip + side, tip - side, p0 - side]), MECH)
		ci.draw_colored_polygon(PackedVector2Array([p0 + side, tip + side, tip + side * 0.3, p0 + side * 0.3]), MECH_L)
		# heat band
		var hb := dir * 30.0
		ci.draw_colored_polygon(PackedVector2Array([hb + side * 1.25, hb + dir * 3.0 + side * 1.25, hb + dir * 3.0 - side * 1.25, hb - side * 1.25]), MECH_D)
		# flared muzzle (bigger)
		var m0 := tip - dir * 2.0
		var m1 := tip + dir * 6.0
		var ms := dir.orthogonal()
		ci.draw_colored_polygon(PackedVector2Array([m0 + ms * 3.6, m1 + ms * 4.8, m1 - ms * 4.8, m0 - ms * 3.6]), ACC)
		ci.draw_colored_polygon(PackedVector2Array([m1 - dir * 1.4 + ms * 2.0, m1 + ms * 2.0, m1 - ms * 2.0, m1 - dir * 1.4 - ms * 2.0]), MECH_D)
		if firing > 0.0:
			glow(ci, m1 + dir * 2.0, 2.4 * firing, SHOT)
	# receiver
	rr(ci, Rect2(Vector2(-15, -17) + sh, Vector2(30, 34)), 5, SHADOW)
	rr(ci, Rect2(-15, -17, 30, 34), 5, MECH)
	rr(ci, Rect2(-13, -15, 13, 12), 3, MECH_L)
	for k in range(4):
		rect(ci, Rect2(2, -12 + k * 6, 9, 2), MECH_D)
	rivets(ci, [Vector2(-11, 12), Vector2(10, 13), Vector2(10, -13)])
	ci.draw_circle(Vector2(-6, 5), 3.0, ACC)
	# ammo drum on the side
	ci.draw_circle(Vector2(-15, 15) + sh * 0.6, 9.5, SHADOW)
	ci.draw_circle(Vector2(-15, 15), 9.5, MECH_D)
	ci.draw_circle(Vector2(-16, 14), 7.5, MECH_L)
	for k in range(6):
		var a2 := t * 2.0 + TAU * float(k) / 6.0
		ci.draw_circle(Vector2(-16, 14) + Vector2(cos(a2), sin(a2)) * 4.6, 1.5, BRASS)
	ci.draw_circle(Vector2(-16, 14), 2.0, ACC)


## Knockback MG (B, one barrel): a single long barrel in front of a gyroscope
## gravity core with three spinning violet rings.
static func _knockback_mg(ci: CanvasItem, sh: Vector2, t: float, firing: float) -> void:
	barrel(ci, sh, 6, 44, 0, 4.0)
	for x in [18.0, 30.0]:
		rect(ci, Rect2(x, -5.5, 3, 11), MECH_D)
		rect(ci, Rect2(x + 0.5, -4.5, 2, 2), VIO)
	muzzle(ci, 47, 0, 4.6, VIO_L, 4.0)
	rect(ci, Rect2(43, -5.6, 1.6, 11.2), VIO_D)
	if firing > 0.0:
		glow(ci, Vector2(49, 0), 3.0 * firing, VIO)
	ci.draw_circle(Vector2(-3, 0) + sh * 0.6, 16, SHADOW)
	ci.draw_circle(Vector2(-3, 0), 16, MECH)
	ci.draw_circle(Vector2(-4, -1), 14, MECH_L)
	for k in range(3):
		ellipse(ci, Vector2(-3, 0), 12.5, 5.0, t * 3.0 + TAU * float(k) / 6.0, VIO, 1.3)
	glow(ci, Vector2(-3, 0), 4.5 + 1.5 * firing, VIO_D)
	ci.draw_circle(Vector2(-3, 0), 3.4, VOID)
	ci.draw_circle(Vector2(-4.2, -1.2), 1.0, VIO_L)


## Laser MG (B, bigger): long finned barrel glowing along its heat
## segments, big lens at the tip.
static func _laser_mg(ci: CanvasItem, sh: Vector2, t: float, firing: float) -> void:
	barrel(ci, sh, 4, 56, 0, 5.0)
	for k in range(7):
		var x := 14.0 + k * 5.6
		rect(ci, Rect2(Vector2(x, -11) + sh * 0.5, Vector2(2.6, 22)), SHADOW)
		rect(ci, Rect2(x, -11, 2.6, 22), MECH_D)
		rect(ci, Rect2(x, -11, 2.6, 3.5), MECH_L)
	var heat := 0.5 + 0.5 * firing
	for k in range(4):
		rect(ci, Rect2(8 + k * 4.5, -1.8, 3.2, 3.6), Color(SHOT, (0.45 + 0.15 * k) * heat + 0.2))
	ci.draw_arc(Vector2(57, 0), 5.6, 0, TAU, 20, ACC, 2.0)
	glow(ci, Vector2(57, 0), 3.8 + 1.2 * firing, CORE)
	rr(ci, Rect2(Vector2(-15, -14) + sh, Vector2(25, 28)), 5, SHADOW)
	rr(ci, Rect2(-15, -14, 25, 28), 5, MECH)
	rr(ci, Rect2(-13, -12, 11, 10), 3, MECH_L)
	glow(ci, Vector2(-3, 0), 4.5, SHOT)
	rivets(ci, [Vector2(-11, 10), Vector2(6, -10), Vector2(6, 10)])


## Sawblade MG (A body + B's single barrel): a big spinning saw on the
## receiver, one launcher barrel with a loaded blade.
static func _sawblade_mg(ci: CanvasItem, sh: Vector2, t: float, firing: float) -> void:
	barrel(ci, sh, 6, 46, 0, 5.4)
	rect(ci, Rect2(12, -1, 34, 2), MECH_D)
	muzzle(ci, 48, 0, 6.2, ACC, 4.0)
	saw_blade(ci, Vector2(38, 0), 6.0, t * 9.0, sh * 0.5)
	saw_blade(ci, Vector2(-4, 0), 18.0, t * 5.0, sh)
	rr(ci, Rect2(-10, 14, 18, 6), 2, ACC)
	rect(ci, Rect2(-8, 15.5, 14, 1.4), MECH_D)


## Flame MG (B): four-barrel gatling with a burning muzzle ring, a spinning
## hub glowing red and a fuel hose.
static func _flame_mg(ci: CanvasItem, sh: Vector2, t: float, firing: float) -> void:
	for k in range(4):
		barrel(ci, sh, 4, 46, (float(k) - 1.5) * 4.6, 1.9)
	rr(ci, Rect2(40, -11, 6, 22), 2, MECH_D)
	var flick := 0.8 + 0.2 * sin(t * 23.0)
	glow(ci, Vector2(47, 0), (3.4 + 1.6 * firing) * flick, FIRE)
	ci.draw_circle(Vector2(47, 0), 1.8, FIRE_L)
	ci.draw_circle(Vector2(-4, 0) + sh * 0.6, 15, SHADOW)
	ci.draw_circle(Vector2(-4, 0), 15, MECH)
	for k in range(4):
		var a := t * (8.0 + 10.0 * firing) + TAU * float(k) / 4.0
		ci.draw_circle(Vector2(-4, 0) + Vector2(cos(a), sin(a)) * 8, 3, MECH_L)
	glow(ci, Vector2(-4, 0), 4, FIRE)
	ci.draw_polyline(PackedVector2Array([Vector2(-14, 12), Vector2(-2, 16), Vector2(10, 13)]), RED_TANK, 3.0)


## Laser Chainsaw (A): a saw disc whose edge is a ring of laser, spinning.
static func _laser_chainsaw(ci: CanvasItem, sh: Vector2, t: float, firing: float) -> void:
	var spin := t * (6.0 + 10.0 * firing)
	ci.draw_circle(Vector2.ZERO, 28, Color(SHOT, 0.12 + 0.1 * firing))
	ci.draw_arc(Vector2.ZERO, 25, 0, TAU, 48, SHOT, 3.0)
	ci.draw_arc(Vector2.ZERO, 25, 0, TAU, 48, CORE, 1.2)
	for k in range(12):
		var a := spin + TAU * float(k) / 12.0
		ci.draw_line(Vector2(cos(a), sin(a)) * 20, Vector2(cos(a + 0.12), sin(a + 0.12)) * 29, CORE, 1.4)
	ci.draw_circle(sh * 0.4, 18, SHADOW)
	ci.draw_circle(Vector2.ZERO, 18, MECH)
	ci.draw_circle(Vector2(-1, -1), 16, MECH_L)
	for k in range(4):
		var a := spin + TAU * float(k) / 4.0
		ci.draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * 15, MECH_D, 3)
	glow(ci, Vector2.ZERO, 5, SHOT)


## Heavy Laser (A, moved back, double calibre): a huge barrel from behind
## the centre, three capacitor rings and a big lens.
static func _heavy_laser(ci: CanvasItem, sh: Vector2, t: float, firing: float) -> void:
	barrel(ci, sh, -16, 46, 0, 14.0)
	for x in [-4.0, 10.0, 24.0]:
		rr(ci, Rect2(Vector2(x, -17.5) + sh * 0.5, Vector2(6, 35)), 2, SHADOW)
		rr(ci, Rect2(x, -17.5, 6, 35), 2, MECH_D)
		rect(ci, Rect2(x + 1.5, -15, 3, 4), SHOT)
		rect(ci, Rect2(x + 1.5, 11, 3, 4), Color(SHOT, 0.6))
	muzzle(ci, 50, 0, 16.0, ACC, 4.0)
	ci.draw_arc(Vector2(50, 0), 11, 0, TAU, 32, MECH_D, 3.0)
	glow(ci, Vector2(50, 0), 8.0 + 3.0 * firing, CORE)
	rivets(ci, [Vector2(-12, -10), Vector2(-12, 10), Vector2(38, -10), Vector2(38, 10)])


## Automatic Cannon (C): revolver cannon, a six-round cylinder turning one
## step per shot behind the barrel.
static func _auto_cannon(ci: CanvasItem, sh: Vector2, t: float, firing: float) -> void:
	barrel(ci, sh, 10, 50, 0, 5.5)
	rect(ci, Rect2(30, -6.8, 4, 13.6), MECH_D)
	muzzle(ci, 52, 0, 6.6, ACC, 4.0)
	if firing > 0.0:
		glow(ci, Vector2(54, 0), 4.0 * firing, SHOT)
	ci.draw_circle(Vector2(-2, 0) + sh * 0.6, 16.5, SHADOW)
	ci.draw_circle(Vector2(-2, 0), 16.5, MECH)
	ci.draw_circle(Vector2(-3, -1), 14.5, MECH_L)
	var step := floorf(t * 5.0) * TAU / 6.0
	for k in range(6):
		var a := step + TAU * float(k) / 6.0
		var p := Vector2(-2, 0) + Vector2(cos(a), sin(a)) * 9.5
		ci.draw_circle(p, 4.2, MECH_D)
		ci.draw_circle(p, 2.8, BRASS)
		ci.draw_circle(p + Vector2(-0.6, -0.6), 1.0, CORE)
	ci.draw_circle(Vector2(-2, 0), 3.5, ACC)


## Siege Cannon (C): big-bore mortar seen from above with a shell rack.
static func _siege_cannon(ci: CanvasItem, sh: Vector2, t: float, firing: float) -> void:
	for k in range(4):
		var p := Vector2(-20, -12 + k * 8)
		ci.draw_circle(p + sh * 0.4, 3.6, SHADOW)
		ci.draw_circle(p, 3.6, MECH)
		ci.draw_circle(p + Vector2(-1, -1), 1.6, ACC)
	ci.draw_circle(Vector2(8, 0) + sh, 19, SHADOW)
	ci.draw_circle(Vector2(8, 0), 19, MECH)
	ci.draw_circle(Vector2(7, -1), 16, MECH_L)
	ci.draw_circle(Vector2(8, 0), 12, MECH_D)
	ci.draw_circle(Vector2(8, 0), 9, Color("120E0C"))
	ci.draw_arc(Vector2(8, 0), 18, -0.6, 0.6, 16, ACC, 2.4)
	for k in range(4):
		var a := PI * 0.25 + PI * 0.5 * float(k)
		ci.draw_circle(Vector2(8, 0) + Vector2(cos(a), sin(a)) * 14, 1.4, MECH_D)
	if firing > 0.0:
		ci.draw_circle(Vector2(8, 0), 9 * firing, Color(SHOT, 0.6 * firing))
		ci.draw_circle(Vector2(8, 0), 20 + 8 * (1.0 - firing), Color(0.6, 0.55, 0.5, 0.35 * firing))


## Long-range Knockback Cannon (B, bigger calibre): a gravity orb with
## spinning rings behind a fat barrel.
static func _knockback_cannon(ci: CanvasItem, sh: Vector2, t: float, firing: float) -> void:
	barrel(ci, sh, 6, 52, 0, 9.0)
	for x in [20.0, 34.0]:
		rect(ci, Rect2(x, -11, 4, 22), MECH_D)
		rect(ci, Rect2(x + 1, -9, 2, 3), VIO)
	muzzle(ci, 55, 0, 10.0, VIO_L, 4.0)
	rect(ci, Rect2(50, -10.5, 1.8, 21), VIO_D)
	if firing > 0.0:
		glow(ci, Vector2(57, 0), 6.0 * firing, VIO)
	ci.draw_circle(Vector2(-6, 0) + sh * 0.6, 17.5, SHADOW)
	ci.draw_circle(Vector2(-6, 0), 17.5, MECH)
	glow(ci, Vector2(-6, 0), 9 + 2.0 * firing, VIO_D)
	ci.draw_circle(Vector2(-6, 0), 7, VOID)
	ci.draw_circle(Vector2(-8, -2), 1.6, VIO_L)
	for k in range(3):
		ellipse(ci, Vector2(-6, 0), 15.5, 5.5, t * 3.0 + TAU * float(k) / 6.0, VIO, 1.4)


## Flame Cannon (A): a red-hot barrel and a glowing breech.
static func _flame_cannon(ci: CanvasItem, sh: Vector2, t: float, firing: float) -> void:
	barrel(ci, sh, 4, 52, 0, 7.0)
	var heat := 0.75 + 0.25 * sin(t * 4.0)
	rect(ci, Rect2(30, -7, 22, 14), Color(FIRE_D, heat))
	rect(ci, Rect2(40, -7, 12, 14), Color(FIRE, heat))
	rect(ci, Rect2(40, -7, 12, 3), Color(FIRE_L, heat))
	muzzle(ci, 54, 0, 8.0, FIRE_L, 4.0)
	glow(ci, Vector2(55, 0), 3.0 + 4.0 * firing, FIRE)
	ci.draw_colored_polygon(ngon(Vector2(-4, 0) + sh * 0.6, 16, 6, PI / 6.0), SHADOW)
	ci.draw_colored_polygon(ngon(Vector2(-4, 0), 16, 6, PI / 6.0), MECH)
	ci.draw_colored_polygon(ngon(Vector2(-5, -1), 12, 6, PI / 6.0), MECH_L)
	glow(ci, Vector2(-4, 0), 4.5 + 0.8 * sin(t * 9.0), FIRE)


## Knockback Laser (A): a wide flat slit emitter with a violet edge.
static func _knockback_laser(ci: CanvasItem, sh: Vector2, t: float, firing: float) -> void:
	rr(ci, Rect2(Vector2(6, -16) + sh, Vector2(32, 32)), 4, SHADOW)
	rr(ci, Rect2(6, -16, 32, 32), 4, MECH)
	rr(ci, Rect2(8, -14, 28, 10), 3, MECH_L)
	for k in range(3):
		rect(ci, Rect2(12 + k * 7, 4, 3, 9), MECH_D)
	rect(ci, Rect2(37, -15, 4, 30), VIO_D)
	rect(ci, Rect2(38, -14, 2, 28), Color(VIO_L, 0.6 + 0.4 * firing))
	if firing > 0.0:
		rect(ci, Rect2(40, -16, 4 * firing + 1, 32), Color(VIO, 0.4 * firing))
	ci.draw_circle(Vector2(-6, 0) + sh * 0.6, 12, SHADOW)
	ci.draw_circle(Vector2(-6, 0), 12, MECH)
	ci.draw_circle(Vector2(-7, -1), 10, MECH_L)
	glow(ci, Vector2(-6, 0), 4 + 0.6 * sin(t * 5.0), VIO)


## Flame Laser (A): a lens with a fire-red core and heat fins that glow
## hotter as the beam ramps up (extra 0..1).
static func _flame_laser(ci: CanvasItem, sh: Vector2, t: float, firing: float, ramp: float) -> void:
	barrel(ci, sh, 4, 46, 0, 5.0)
	for k in range(5):
		rect(ci, Rect2(Vector2(12 + k * 6, -11) + sh * 0.5, Vector2(2.6, 22)), SHADOW)
		rect(ci, Rect2(12 + k * 6, -11, 2.6, 22), MECH_D)
		rect(ci, Rect2(12 + k * 6, -11, 2.6, 4), FIRE.lerp(FIRE_L, ramp))
		rect(ci, Rect2(12 + k * 6, 7, 2.6, 4), Color(FIRE.lerp(FIRE_L, ramp), 0.4 + 0.6 * ramp))
	ci.draw_arc(Vector2(47, 0), 5.5, 0, TAU, 20, ACC, 2)
	glow(ci, Vector2(47, 0), 3.4 + 2.0 * ramp, FIRE_L)
	ci.draw_circle(Vector2(-4, 0) + sh * 0.6, 13, SHADOW)
	ci.draw_circle(Vector2(-4, 0), 13, MECH)
	glow(ci, Vector2(-4, 0), 5 + 1.5 * ramp, FIRE)


# ------------------------------------------------------------ beams (local, from the muzzle along +x)

static func draw_beam(ci: CanvasItem, weapon_id: StringName, start: float, length: float, width: float, t: float, ramp: float = 0.0) -> void:
	if length <= 1.0:
		return
	var end := start + length
	var flick := 0.9 + 0.1 * sin(t * 40.0)
	match weapon_id:
		&"flame_laser":
			var w := width * (1.0 + 1.2 * ramp) * flick
			rect(ci, Rect2(start, -w, length, w * 2.0), Color(FIRE, 0.18))
			rect(ci, Rect2(start, -w * 0.5, length, w), FIRE)
			rect(ci, Rect2(start, -w * 0.22, length, w * 0.44), FIRE_L.lerp(CORE, ramp))
			var step := 26.0
			var x := start + fposmod(t * 160.0, step)
			while x < end:
				flame_puff(ci, Vector2(x, sin(x * 0.13 + t * 9.0) * w * 0.4), w * 0.35)
				x += step
			glow(ci, Vector2(end, 0), w * 0.8, FIRE_L)
		&"laser_chainsaw":
			var w := width * flick
			rect(ci, Rect2(start, -w, length, w * 2.0), Color(SHOT, 0.16))
			rect(ci, Rect2(start, -w * 0.5, length, w), SHOT)
			rect(ci, Rect2(start, -w * 0.18, length, w * 0.36), CORE)
			# saw teeth running along both edges
			var step := 10.0
			var x := start + fposmod(t * 300.0, step)
			while x < end:
				ci.draw_colored_polygon(PackedVector2Array([Vector2(x, -w * 0.5), Vector2(x + 4, -w * 0.95), Vector2(x + 6, -w * 0.5)]), CORE)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(x + 3, w * 0.5), Vector2(x + 7, w * 0.95), Vector2(x + 9, w * 0.5)]), CORE)
				x += step
		_:
			# heavy laser and any other beam: wide glow, body, hot core, pulses
			var w := width * flick
			rect(ci, Rect2(start, -w * 0.8, length, w * 1.6), Color(SHOT, 0.18))
			rect(ci, Rect2(start, -w * 0.5, length, w), SHOT)
			rect(ci, Rect2(start, -w * 0.24, length, w * 0.48), CORE)
			var step := 60.0
			var x := start + fposmod(t * 600.0, step)
			while x < end:
				rect(ci, Rect2(x, -w * 0.55, 14, w * 1.1), Color(CORE, 0.35))
				x += step
			glow(ci, Vector2(start, 0), w * 0.32, CORE)


# ------------------------------------------------------------ projectiles (local, facing +x)

static func draw_projectile(ci: CanvasItem, weapon_id: StringName, radius: float, spin: float, age: float) -> void:
	match weapon_id:
		&"scatter_machine_gun":
			ci.draw_line(Vector2(-9, 0), Vector2(0, 0), Color(SHOT, 0.5), 2.6)
			ci.draw_circle(Vector2.ZERO, 2.2, SHOT)
			ci.draw_circle(Vector2.ZERO, 1.1, CORE)
		&"knockback_machine_gun":
			ci.draw_line(Vector2(-9, 0), Vector2.ZERO, Color(VIO, 0.5), 2.6)
			ci.draw_circle(Vector2.ZERO, 2.4, VIO_L)
			var ph := fposmod(age * 6.0, 1.0)
			ci.draw_arc(Vector2(-2, 0), 4.0 + 4.0 * ph, -0.9, 0.9, 12, Color(VIO, 0.8 * (1.0 - ph)), 1.6)
		&"laser_machine_gun":
			ci.draw_line(Vector2(-16, 0), Vector2.ZERO, Color(SHOT, 0.35), 5.0)
			ci.draw_line(Vector2(-16, 0), Vector2.ZERO, CORE, 2.0)
		&"sawblade_machine_gun":
			saw_blade(ci, Vector2.ZERO, maxf(radius, 6.0), spin * 1.5, Vector2(1.5, 2.2))
		&"flame_machine_gun":
			for k in range(3):
				flame_puff(ci, Vector2(-k * radius * 0.7, sin(age * 30.0 + k) * 1.5), radius * (0.9 - k * 0.2))
			ci.draw_circle(Vector2.ZERO, radius * 0.35, CORE)
		&"automatic_cannon":
			ci.draw_line(Vector2(-12, 0), Vector2.ZERO, Color(SHOT, 0.35), 4.0)
			ci.draw_circle(Vector2.ZERO, radius * 0.75, MECH)
			ci.draw_circle(Vector2(-1, -1), radius * 0.35, BRASS)
		&"siege_cannon":
			# a big shell arcing up: drawn larger in the middle of its flight
			ci.draw_circle(Vector2(3, 5), radius * 1.4, SHADOW)
			ci.draw_circle(Vector2.ZERO, radius * 1.4, MECH)
			ci.draw_circle(Vector2(-2, -2), radius * 0.6, MECH_L)
			ci.draw_circle(Vector2(1, 1), radius * 0.35, ACC)
		&"knockback_cannon":
			glow(ci, Vector2.ZERO, radius, VIO)
			ci.draw_circle(Vector2.ZERO, radius * 0.6, VOID)
			for k in range(2):
				var ph := fposmod(age * 3.0 + k * 0.5, 1.0)
				ci.draw_arc(Vector2(-radius * 2.0 * ph, 0), radius * (1.4 + ph), PI * 0.5, PI * 1.5, 16, Color(VIO_L, 0.7 * (1.0 - ph)), 1.6)
		&"flame_cannon":
			for k in range(4):
				flame_puff(ci, Vector2(-k * radius * 0.8, sin(age * 20.0 + k * 1.7) * radius * 0.3), radius * (1.0 - k * 0.2))
			ci.draw_circle(Vector2.ZERO, radius * 0.5, CORE)
		_:
			ci.draw_circle(Vector2.ZERO, radius, SHOT)


## Knockback Laser's travelling wave front (local, wave travels along +x).
static func draw_wave(ci: CanvasItem, half_length: float, thickness: float, age: float) -> void:
	var r := half_length * 1.6
	var c := Vector2(-r + thickness * 0.3, 0)
	var span := asin(clampf(half_length / r, 0.0, 1.0))
	var pulse := 0.85 + 0.15 * sin(age * 12.0)
	ci.draw_arc(c, r, -span, span, 32, Color(VIO, 0.16), thickness * 1.6)
	ci.draw_arc(c, r, -span, span, 32, Color(VIO, 0.4 * pulse), thickness * 0.8)
	ci.draw_arc(c, r, -span, span, 32, VIO, maxf(3.0, thickness * 0.25))
	ci.draw_arc(c, r, -span, span, 32, VIO_L, 1.6)
	for k in range(5):
		var a := lerpf(-span, span, (float(k) + 0.5) / 5.0)
		var p := c + Vector2(cos(a), sin(a)) * r
		ci.draw_line(p, p - Vector2(10 + 6 * sin(age * 9.0 + k), 0), Color(VIO_L, 0.5), 1.2)
