extends Node2D

## Fusion weapon turret (the rotating part). Draws the picked design for the
## parent FusionWeapon's weapon_type_id via FusionArt, moves the Muzzle to the
## new barrel tip, and draws the styled beam in place of the plain Line2D
## (which stays as the visibility / length / width source, made transparent).
## Presentation only.

var _t: float = 0.0
var _firing: float = 0.0
var _last_cooldown: float = 0.0
var _weapon: Node
var _weapon_id: StringName = &""
var _beam: Line2D


func _ready() -> void:
	_weapon = get_parent()
	_weapon_id = StringName(_weapon.get("weapon_type_id")) if _weapon != null else &""
	_t = randf() * 10.0
	var muzzle := get_node_or_null("Muzzle") as Node2D
	if muzzle != null:
		muzzle.position.x = FusionArt.muzzle_x(_weapon_id)
		_beam = muzzle.get_node_or_null("Beam") as Line2D
		if _beam != null:
			_beam.self_modulate.a = 0.0


func _process(delta: float) -> void:
	_t += delta
	_firing = maxf(_firing - delta / 0.12, 0.0)
	if _weapon != null:
		var cooldown := float(_weapon.get("_cooldown"))
		# A shot resets the cooldown upward.
		if cooldown > _last_cooldown + 0.0001:
			_firing = 1.0
		_last_cooldown = cooldown
	if _beam != null and _beam.visible:
		_firing = 1.0
	queue_redraw()


func _draw() -> void:
	var sh := Palette.local_shadow_offset(self) * 0.5
	var ramp := 0.0
	if _weapon_id == &"flame_laser" and _weapon != null:
		ramp = clampf(float(_weapon.get("_doublings")) / 6.0, 0.0, 1.0)
	FusionArt.draw_turret(self, _weapon_id, sh, _t, _firing, ramp)
	if _beam != null and _beam.visible and _beam.points.size() >= 2:
		var start := FusionArt.muzzle_x(_weapon_id)
		FusionArt.draw_beam(self, _weapon_id, start, _beam.points[1].x, _beam.width, _t, ramp)
