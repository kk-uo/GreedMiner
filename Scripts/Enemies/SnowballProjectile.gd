extends HostileProjectile

## Zero for ordinary attacks; the boss's special projectile applies a freeze.
var freeze_duration: float = 0.0

const SnowImpact := preload("res://Scripts/VFX/SnowImpact.gd")
const SHADE := Color("B5D3E6")
const SNOW := Color("E4F3FB")
const ICE := Color("9FE7FF")
## Drawn radius: the wizard's snowball and the boss's freezing snowball.
const SMALL_RADIUS: float = 6.0
const BIG_RADIUS: float = 22.0

var _spin: float = 0.0


func _process(delta: float) -> void:
	_spin += delta
	queue_redraw()


func _on_ship_hit() -> void:
	super()
	var battle := get_tree().current_scene
	if battle != null:
		var impact := SnowImpact.new()
		impact.big = freeze_duration > 0.0
		battle.add_child(impact)
		impact.global_position = global_position
	if freeze_duration > 0.0 and battle != null and battle.has_method("freeze_ship_input"):
		battle.call("freeze_ship_input", freeze_duration)


## Packed snowball with a snowy trail; the boss's freezing one is big, glows
## cyan and has ice shards spinning round it.
func _draw() -> void:
	var big := freeze_duration > 0.0
	var radius := BIG_RADIUS if big else SMALL_RADIUS
	var back := -direction.normalized()
	var side := Vector2(-back.y, back.x)
	var trail := 6 if big else 4
	for index in range(1, trail + 1):
		var k := float(index)
		var wobble := side * sin(_spin * 14.0 + k) * radius * 0.12
		draw_circle(back * k * radius * 0.6 + wobble, radius * (0.75 - k * 0.09), Color(1, 1, 1, 0.4 - k * 0.055))
	draw_circle(Vector2(4.0, 6.0) * (radius / 10.0), radius, Palette.SHADOW_COLOR)
	if big:
		draw_circle(Vector2.ZERO, radius * (1.45 + 0.1 * sin(_spin * 12.0)), Color(ICE, 0.22))
	draw_circle(Vector2.ZERO, radius, SHADE)
	draw_circle(Vector2(-0.12, -0.12) * radius, radius * 0.86, SNOW)
	draw_arc(Vector2.ZERO, radius * 0.6, _spin * 6.0, _spin * 6.0 + 2.2, 10, SHADE, maxf(radius * 0.08, 1.0))
	if big:
		for index in range(5):
			var a := _spin * 4.0 + TAU * float(index) / 5.0
			var dir := Vector2(cos(a), sin(a))
			var perp := Vector2(-dir.y, dir.x)
			var base := dir * radius * 0.85
			draw_colored_polygon(PackedVector2Array([base + perp * 4.0, base + dir * 11.0, base - perp * 4.0]), Color("2B8FB0"))
			draw_colored_polygon(PackedVector2Array([base + perp * 2.0, base + dir * 9.0, base]), ICE)
	draw_circle(Vector2(-0.38, -0.38) * radius, radius * 0.24, Color.WHITE)
