extends RefCounted

## Ghost Bullet presentation: the projectile turns into a translucent pale
## spirit-shot - a see-through body with a soft halo and a wavering wisp
## trailing behind it (afterimages). Used by MachineGunProjectile and
## DwarfCannonProjectile when ghost piercing is on. Presentation only.
## Load with preload(); no class_name on purpose.

const BODY := Color("CFF6FF")
const GLOW := Color("8FE3FF")
const CORE := Color("FFFFFF")


## Draws in the projectile's local space; `direction` = flight direction,
## `radius` ~ the normal projectile's radius.
static func draw(ci: CanvasItem, direction: Vector2, time: float, radius: float, seed_value: float = 0.0) -> void:
	var d := direction.normalized()
	var side := d.orthogonal()
	var flicker := 0.85 + 0.15 * sin(time * 23.0 + seed_value * 7.0)
	# Wavering wisp tail made of fading afterimages.
	var steps := 7
	for k in range(steps, 0, -1):
		var t := float(k) / float(steps)
		var wave := sin(time * 16.0 - t * 5.0 + seed_value * 3.0) * radius * 0.7 * t
		var at := -d * radius * 4.2 * t + side * wave
		ci.draw_circle(at, radius * lerpf(1.05, 0.35, t), Color(GLOW, 0.32 * (1.0 - t) * flicker))
	# Halo, see-through body and a bright core.
	ci.draw_circle(Vector2.ZERO, radius * 2.0, Color(GLOW, 0.14 * flicker))
	ci.draw_circle(Vector2.ZERO, radius * 1.15, Color(BODY, 0.55 * flicker))
	ci.draw_circle(d * radius * 0.25, radius * 0.55, Color(CORE, 0.75 * flicker))
