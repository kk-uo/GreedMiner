extends Node2D

## Fusion weapon turret (the rotating part). Draws the picked design for the
## parent FusionWeapon's weapon_type_id via FusionArt, moves the Muzzle to the
## new barrel tip, and draws the styled beam in place of the plain Line2D
## (which stays as the visibility / length / width source, made transparent).
## Presentation only.

## Drawn length of the Laser Chainsaw's endless beams (covers any screen).
const SAW_BEAM_LENGTH: float = 4000.0

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
	if _weapon_id == &"laser_chainsaw" and _weapon != null:
		_firing = float(_weapon.get("saw_engaged"))
	queue_redraw()


func _draw() -> void:
	var sh := Palette.local_shadow_offset(self) * 0.5
	var ramp := 0.0
	if _weapon_id == &"flame_laser" and _weapon != null:
		ramp = clampf(float(_weapon.get("_doublings")) / 6.0, 0.0, 1.0)
	if _weapon_id == &"laser_chainsaw" and _weapon != null and not bool(_weapon.get("assembly_mode")):
		# The cutting reach: a faint laser ring at the real attack radius.
		var reach := float(_weapon.call("get_modified_attack_range", float(_weapon.get("attack_range"))))
		FusionArt.laser_saw_reach(self, reach, _t, _firing)
		var power := float(_weapon.get("saw_beam_power"))
		var count := int(_weapon.get("saw_beam_count"))
		if power > 0.01 and count > 0:
			var base_angle := float(_weapon.get("saw_beam_angle")) - global_rotation
			var width := float(_weapon.call("get_modified_beam_width", float(_weapon.get("beam_width"))))
			for k in range(count):
				draw_set_transform(Vector2.ZERO, base_angle + TAU * float(k) / float(count), Vector2.ONE)
				FusionArt.laser_saw_beam(self, 24.0, SAW_BEAM_LENGTH, width * power, _t, power)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	FusionArt.draw_turret(self, _weapon_id, sh, _t, _firing, ramp)
	if _beam != null and _beam.visible and _beam.points.size() >= 2:
		var start := FusionArt.muzzle_x(_weapon_id)
		FusionArt.draw_beam(self, _weapon_id, start, _beam.points[1].x, _beam.width, _t, ramp)
