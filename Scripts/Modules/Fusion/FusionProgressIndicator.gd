class_name FusionProgressIndicator
extends Node2D

## "Forge hammer" weapon-fusion presentation.
## While fusing, BaseMain drives the two real module nodes with forge_pose():
## the dragged weapon winds back and slams into the target three times
## (sparks + jolt on every hit, both glowing hotter), then sinks into it.
## This node draws the hit pips, the heat glow, sparks and the final flash;
## play_reveal() then pops the result out white-hot and cools it down.

const HITS: Array[float] = [0.28, 0.58, 0.86]
const RECOIL: float = 0.08
const REVEAL_TIME: float = 0.75
const HOT := Color(1.0, 0.47, 0.16)

var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()
		if _fx != null:
			_fx.queue_redraw()
var label_text: String = "FUSING"
## Seconds the whole fuse takes (used to time sparks).
var duration: float = 1.0
## Unit direction from the target cell centre toward the dragged weapon.
var direction: Vector2 = Vector2.LEFT

var _fx: Node2D
var _reveal_t: float = -1.0
var _result: Node2D
var _result_scale: Vector2 = Vector2.ONE
var _result_modulate: Color = Color.WHITE


func _ready() -> void:
	z_index = 40
	_fx = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_fx.material = mat
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	set_process(false)
	queue_redraw()


# ------------------------------------------------------------------
# Pose shared with BaseMain
# ------------------------------------------------------------------

## Returns {offset, push, squash, shake, heat, hits} for fuse progress u.
## offset: distance of the dragged weapon from the target centre along
## `direction`; push: how far the target is shoved the other way.
static func forge_pose(u: float, start_offset: float) -> Dictionary:
	u = clampf(u, 0.0, 1.0)
	var offset := 0.0
	var hits := 0
	var prev_t := 0.0
	var prev_off := start_offset
	var done := true
	for i in HITS.size():
		var h: float = HITS[i]
		var back := 40.0 + 6.0 * i
		var contact := 24.0 - 4.0 * i
		if u < h:
			var k := (u - prev_t) / (h - prev_t)
			if k < 0.6:
				offset = lerpf(prev_off, back, _ease_out(k / 0.6))
			else:
				offset = lerpf(back, contact, _ease_in((k - 0.6) / 0.4))
			done = false
			break
		prev_t = h
		prev_off = contact
		hits = i + 1
	if done:
		var k := (u - HITS[HITS.size() - 1]) / (1.0 - HITS[HITS.size() - 1])
		offset = lerpf(prev_off, 0.0, _ease_in(k))
	var since := _time_since_hit(u)
	var squash := 1.0
	var shake := 0.0
	var push := 0.0
	if since < RECOIL:
		var r := 1.0 - since / RECOIL
		squash = 1.0 - 0.18 * r
		shake = 4.0 * r
		push = 4.0 * r
		offset = 24.0 - 4.0 * float(maxi(hits - 1, 0))
	var heat := 0.0
	if hits > 0:
		heat = clampf(float(hits) / 3.0 + (u - HITS[hits - 1]) * 0.6, 0.0, 1.0)
	return {
		"offset": offset, "push": push, "squash": squash,
		"shake": shake, "heat": heat, "hits": hits,
	}


static func heat_color(base: Color, heat: float) -> Color:
	return Color(
		base.r * (1.0 + 0.75 * heat),
		base.g * (1.0 + 0.05 * heat),
		base.b * (1.0 - 0.45 * heat),
		base.a
	)


static func _time_since_hit(u: float) -> float:
	var best := 99.0
	for h: float in HITS:
		if u >= h:
			best = minf(best, u - h)
	return best


static func _ease_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


static func _ease_in(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * t


static func _back_out(t: float, s: float = 1.6) -> float:
	t = clampf(t, 0.0, 1.0) - 1.0
	return t * t * ((s + 1.0) * t + s) + 1.0


# ------------------------------------------------------------------
# Reveal
# ------------------------------------------------------------------

## Call once the fused weapon exists: it pops out white-hot, sheds sparks and
## steam, cools to its normal colour, then this node frees itself.
func play_reveal(result: Node2D) -> void:
	_result = result
	if is_instance_valid(_result):
		_result_scale = _result.scale
		_result_modulate = _result.modulate
	progress = 1.0
	_reveal_t = 0.0
	set_process(true)
	_apply_reveal()


func is_revealing() -> bool:
	return _reveal_t >= 0.0


func _process(delta: float) -> void:
	if _reveal_t < 0.0:
		return
	_reveal_t += delta
	_apply_reveal()
	queue_redraw()
	_fx.queue_redraw()
	if _reveal_t >= REVEAL_TIME:
		if is_instance_valid(_result):
			_result.scale = _result_scale
			_result.modulate = _result_modulate
		queue_free()


func _apply_reveal() -> void:
	if not is_instance_valid(_result):
		return
	var k := clampf(_reveal_t / REVEAL_TIME, 0.0, 1.0)
	var pop := _back_out(minf(k / 0.5, 1.0))
	_result.scale = _result_scale * maxf(pop, 0.05)
	var cool := maxf(0.0, 1.0 - k * 1.4)
	_result.modulate = heat_color(_result_modulate, cool)


# ------------------------------------------------------------------
# Drawing
# ------------------------------------------------------------------

func _draw() -> void:
	if _reveal_t >= 0.0:
		_draw_steam(clampf(_reveal_t / REVEAL_TIME, 0.0, 1.0))
		return
	var hits := 0
	for h: float in HITS:
		if progress >= h:
			hits += 1
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-100.0, -50.0), label_text, HORIZONTAL_ALIGNMENT_CENTER, 200.0, 9, Palette.UI_TEXT)
	for i in 3:
		var r := Rect2(Vector2(-29.0 + i * 21.0, -44.0), Vector2(16.0, 7.0))
		var on := i < hits
		Palette.draw_rounded_rect(self, r.grow(1.5), 3.5, Color(Palette.UI_PANEL, 0.94))
		Palette.draw_rounded_rect(self, r, 3.0, Color(1.0, 0.6, 0.2) if on else Color(0.26, 0.29, 0.4))


func _draw_steam(k: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 6:
		var x := rng.randf_range(-22.0, 22.0)
		var y := -14.0 - k * 46.0 - rng.randf_range(0.0, 14.0)
		var r := 6.0 + k * 11.0
		draw_circle(Vector2(x, y), r, Color(0.8, 0.84, 0.92, 0.35 * (1.0 - k)))


func _draw_fx() -> void:
	if _reveal_t >= 0.0:
		var t := _reveal_t
		var k := clampf(t / REVEAL_TIME, 0.0, 1.0)
		var cool := maxf(0.0, 1.0 - k * 1.4)
		_glow(Vector2.ZERO, 34.0 + 8.0 * cool, HOT, 0.3 * cool)
		if k < 0.2:
			var f := 1.0 - k / 0.2
			_glow(Vector2.ZERO, 14.0 + 30.0 * f, Color(1.0, 0.85, 0.6), 0.6 * f)
			_fx.draw_arc(Vector2.ZERO, 16.0 + 46.0 * (1.0 - f), 0.0, TAU, 40, Color(1.0, 0.9, 0.6, f), 3.0)
		_sparks(31, Vector2.ZERO, t, 26, 150.0, Color(1.0, 0.75, 0.3), 0.6)
		return
	var pose := forge_pose(progress, 0.0)
	var heat: float = pose["heat"]
	_glow(Vector2.ZERO, 30.0 + 12.0 * heat, HOT, 0.25 * heat)
	for i in HITS.size():
		var h: float = HITS[i]
		if progress < h:
			continue
		var since := (progress - h) * duration
		var contact := direction * (24.0 - 4.0 * i) * 0.5
		_sparks(11 + i, contact, since, 14 + 5 * i, 110.0 + 30.0 * i, Color(1.0, 0.8, 0.35), 0.45)
		if since < 0.06:
			_glow(contact, 18.0, Color(1.0, 1.0, 0.85), 1.0 - since / 0.06)


func _glow(at: Vector2, radius: float, color: Color, alpha: float) -> void:
	if alpha <= 0.01 or radius <= 0.0:
		return
	for i in range(5, 0, -1):
		var f := float(i) / 5.0
		_fx.draw_circle(at, radius * f, Color(color, alpha * 0.16))


func _sparks(seed_value: int, origin: Vector2, t: float, count: int, speed: float, color: Color, life: float) -> void:
	if t < 0.0 or t > life:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var k := t / life
	for i in count:
		var a := rng.randf_range(0.0, TAU)
		var v := rng.randf_range(0.4, 1.0) * speed
		var dir := Vector2.from_angle(a)
		var p := origin + dir * v * t + Vector2(0.0, 70.0 * t * t)
		_fx.draw_line(p, p - dir * v * 0.035, Color(color, 1.0 - k), 2.0)
