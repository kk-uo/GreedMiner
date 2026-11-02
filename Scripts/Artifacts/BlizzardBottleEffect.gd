extends MagicArtifactEffect

## A ship-centred slow aura. Each affected enemy is tracked by source, so
## leaving the radius or ending battle removes only this item's contribution.
var _affected: Dictionary = {}
var _scan_time_left: float = 0.0
## Presentation (Claude sync 91): a frost ring with orbiting snow and wind
## streaks hugging the hull at the aura radius, plus a chill burst and frost
## crystals on every slowed enemy (drawn by `_marks`, above the enemies).
const SNOW := Color("FFFFFF")
const FROST := Color("CBEFFF")
const ICE := Color("7FD8FF")
const FLAKES: int = 34
const CHILL_BURST: float = 0.45
var _t: float = 0.0
var _chill_age: Dictionary = {}  # enemy id -> seconds since it entered
var _marks: Node2D


func _ready() -> void:
	z_index = 2
	_marks = Node2D.new()
	_marks.name = "BlizzardMarks"
	_marks.z_index = 8
	_marks.top_level = true
	add_child(_marks)
	_marks.draw.connect(_draw_marks)
	_refresh_targets()


func _process(delta: float) -> void:
	_t += delta
	for id in _chill_age.keys():
		_chill_age[id] = float(_chill_age[id]) + delta
	queue_redraw()
	if is_instance_valid(_marks):
		_marks.queue_redraw()


func _aura_center() -> Vector2:
	return ship.to_global(Ship.SHIP_SIZE * 0.5)


func _draw() -> void:
	if not is_instance_valid(ship):
		return
	var radius := maxf(float(definition.effect_parameters.get("radius", 200.0)), 0.0)
	var c := to_local(_aura_center())
	# Frost band and a slow rotating dashed rim.
	draw_arc(c, radius, 0.0, TAU, 96, Color(FROST, 0.2), 16.0)
	draw_arc(c, radius, 0.0, TAU, 96, Color(FROST, 0.35), 3.0)
	for k in range(12):
		var a0 := _t * 0.5 + TAU * float(k) / 12.0
		draw_arc(c, radius + 1.5, a0, a0 + 0.3, 6, Color(SNOW, 0.55), 1.6)
	# Wind streaks sweeping around faster than the snow.
	for k in range(5):
		var a := _t * 1.6 + TAU * float(k) / 5.0
		var r := radius + 5.0 + 6.0 * sin(_t * 1.3 + float(k) * 2.1)
		for seg in range(6):
			var sa := a - float(seg) * 0.07
			draw_arc(c, r, sa - 0.07, sa, 3, Color(SNOW, 0.42 * (1.0 - float(seg) / 6.0)), 1.6)
	# Orbiting snowflakes (golden-ratio spread, each with its own speed).
	for k in range(FLAKES):
		var h := fposmod(float(k) * 0.618034 + 0.11, 1.0)
		var speed := 0.45 + 0.5 * fposmod(float(k) * 0.37, 1.0)
		var a := TAU * h + _t * speed
		var r := radius + (fposmod(float(k) * 0.731, 1.0) - 0.45) * 26.0 + 3.0 * sin(_t * 2.0 + float(k))
		var p := c + Vector2.from_angle(a) * r
		var twinkle := 0.55 + 0.45 * sin(_t * 4.0 + float(k) * 1.7)
		if k % 5 == 0:
			_draw_flake(self, p, 3.4, Color(SNOW, 0.9 * twinkle), _t * 1.5 + float(k))
		else:
			draw_circle(p, 1.2 + 1.2 * fposmod(float(k) * 0.29, 1.0), Color(SNOW, 0.8 * twinkle))


func _draw_marks() -> void:
	for id in _affected.keys():
		var value: Variant = _affected[id]
		if not is_instance_valid(value):
			continue
		var enemy := value as BasicEnemy
		var p := enemy.global_position
		var vr := maxf(enemy._get_visual_radius(), 8.0)
		var age := float(_chill_age.get(id, 1.0))
		# Chill burst when the enemy first enters the aura.
		if age < CHILL_BURST:
			var k := age / CHILL_BURST
			_marks.draw_arc(p, vr * (0.8 + 0.9 * k), 0.0, TAU, 24, Color(SNOW, 0.8 * (1.0 - k)), 2.4)
			for n in range(6):
				var a := TAU * float(n) / 6.0 + 0.5
				_draw_flake(_marks, p + Vector2.from_angle(a) * vr * (0.6 + 1.0 * k), 3.0, Color(SNOW, 1.0 - k), a)
		# Frosted ring at the feet and three ice crystals circling slowly.
		_marks.draw_arc(p + Vector2(0, vr * 0.55), vr * 0.9, PI * 0.08, PI * 0.92, 14, Color(ICE, 0.55), 2.0)
		for n in range(3):
			var a := _t * 1.2 + TAU * float(n) / 3.0 + float(id % 7)
			var q := p + Vector2(cos(a) * vr * 1.05, sin(a) * vr * 0.45 - vr * 0.1)
			_marks.draw_colored_polygon(PackedVector2Array([q + Vector2(0, -3.2), q + Vector2(1.8, 0), q + Vector2(0, 3.2), q + Vector2(-1.8, 0)]), Color(FROST, 0.9))
		_draw_flake(_marks, p + Vector2(0, -vr - 7.0), 3.6, Color(SNOW, 0.9), _t)


static func _draw_flake(canvas: CanvasItem, p: Vector2, r: float, color: Color, spin: float) -> void:
	for k in range(3):
		var d := Vector2.from_angle(spin + PI * float(k) / 3.0) * r
		canvas.draw_line(p - d, p + d, color, 1.3)


func _physics_process(delta: float) -> void:
	_scan_time_left -= delta
	if _scan_time_left <= 0.0:
		_scan_time_left = maxf(float(definition.effect_parameters.get("scan_interval", 0.1)), 0.02)
		_refresh_targets()


func _refresh_targets() -> void:
	if not is_instance_valid(ship):
		_release_all()
		return
	var radius := maxf(float(definition.effect_parameters.get("radius", 200.0)), 0.0)
	var fraction := clampf(float(definition.effect_parameters.get("slow_fraction", 0.3)), 0.0, 0.95)
	var center := ship.to_global(Ship.SHIP_SIZE * 0.5)
	var inside: Dictionary = {}
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as BasicEnemy
		if not is_instance_valid(enemy) or enemy.is_dying():
			continue
		var id := enemy.get_instance_id()
		if center.distance_squared_to(enemy.global_position) > radius * radius:
			continue
		inside[id] = enemy
		if not _affected.has(id) and enemy.apply_artifact_target_slow(get_instance_id(), fraction):
			_affected[id] = enemy
			_chill_age[id] = 0.0
	for id in _affected.keys():
		if inside.has(id):
			continue
		var previous: Variant = _affected[id]
		if is_instance_valid(previous):
			(previous as BasicEnemy).remove_artifact_target_slow(get_instance_id())
		_affected.erase(id)
		_chill_age.erase(id)


func _release_all() -> void:
	for value in _affected.values():
		if is_instance_valid(value):
			(value as BasicEnemy).remove_artifact_target_slow(get_instance_id())
	_affected.clear()
	_chill_age.clear()


func cleanup() -> void:
	_release_all()
	queue_free()


func _exit_tree() -> void:
	_release_all()
