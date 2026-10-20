class_name RegenerationModule
extends ShieldModule

## Pulse-based area repair. Targets opt into the lightweight
## `friendly_healing_targets` group and healing interface, so this module does
## not create a larger faction or friendly-unit system.

@export_group("Area Healing")
@export_range(0.0, 1000.0, 0.1) var healing_amount: float = 1.0
@export_range(0.01, 60.0, 0.01) var healing_interval: float = 1.0
@export_range(0.0, 2000.0, 1.0) var healing_radius: float = 128.0

var _pulse_elapsed: float = 0.0

const HealParticles := preload("res://Scripts/VFX/HealParticles.gd")
const HEAL := Color("7CF0A8")
const HEAL_DARK := Color("2FA86A")
const HEAL_LIGHT := Color("D8FFE6")
const BRONZE := Color("B87333")
const BRONZE_DARK := Color("8A4F22")
## Seconds the healing ring takes to sweep out to the healing radius.
const RING_TIME: float = 0.7

var _anim_time: float = 0.0
## Age of the current healing ring in seconds (>= RING_TIME means none).
var _ring_age: float = 99.0
var _ring_strength: float = 1.0


func get_chip_module_kind() -> StringName:
	return &"regeneration"


func get_research_target_id() -> StringName:
	return &"regeneration_module"


func get_effective_healing_amount() -> float:
	return calculate_chip_stat(&"healing_amount", healing_amount)


func get_effective_healing_frequency() -> float:
	return calculate_chip_stat(&"healing_frequency", 1.0 / maxf(healing_interval, 0.01))


func get_effective_healing_interval() -> float:
	var frequency := get_effective_healing_frequency()
	return INF if frequency <= 0.0 else 1.0 / frequency


func get_effective_healing_radius() -> float:
	return calculate_chip_stat(&"healing_radius", healing_radius)


func get_regeneration_per_second() -> float:
	return get_effective_healing_amount() * get_effective_healing_frequency()


func _process(delta: float) -> void:
	_anim_time += delta
	_ring_age += delta
	queue_redraw()
	if not module_active or not is_inside_tree():
		_pulse_elapsed = 0.0
		return
	var interval := get_effective_healing_interval()
	if is_inf(interval):
		return
	_pulse_elapsed += delta
	while _pulse_elapsed + 0.000001 >= interval:
		_pulse_elapsed -= interval
		apply_healing_pulse()


## Heals each eligible friendly once. Queries happen only at pulse time.
func apply_healing_pulse() -> int:
	if not module_active or not is_inside_tree() or not _is_installed_on_ship():
		return 0
	var amount := get_effective_healing_amount()
	var radius := get_effective_healing_radius()
	if amount <= 0.0 or radius < 0.0:
		return 0
	var healed_ids: Dictionary = {}
	var healed_count := 0
	for target in get_tree().get_nodes_in_group("friendly_healing_targets"):
		if not is_instance_valid(target) or target is BasicEnemy or target.is_in_group("enemies"):
			continue
		if not target.has_method("can_receive_healing") or not target.call("can_receive_healing"):
			continue
		if not target.has_method("get_healing_position") or not target.has_method("heal"):
			continue
		var target_id := target.get_instance_id()
		if healed_ids.has(target_id):
			continue
		var target_position: Variant = target.call("get_healing_position")
		if not target_position is Vector2 or global_position.distance_to(target_position) > radius:
			continue
		healed_ids[target_id] = true
		target.call("heal", amount)
		healed_count += 1
		_spawn_heal_particles(target, target_position)
	_play_pulse(healed_count > 0)
	return healed_count


func set_module_active(active: bool) -> void:
	super.set_module_active(active)
	if not active:
		_pulse_elapsed = 0.0


# ==========================================
# Visuals: bronze hex cradle + green crystal, healing ring, heal particles
# ==========================================

## Only a module that sits on a Ship heals; UI previews never do.
func _is_installed_on_ship() -> bool:
	var node := get_parent()
	while node != null:
		if node is Ship:
			return true
		node = node.get_parent()
	return false


func _play_pulse(healed_any: bool) -> void:
	_ring_age = 0.0
	_ring_strength = 1.0 if healed_any else 0.45


func _spawn_heal_particles(target: Node, at: Vector2) -> void:
	var host := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	var area := 60.0 if target is Ship else 16.0
	HealParticles.spawn(host, at, area, 9 if target is Ship else 4)


func _draw() -> void:
	var shadow := Palette.local_shadow_offset(self)
	var breath := 0.5 + 0.5 * sin(_anim_time * 2.4)
	var flash := clampf(1.0 - _ring_age / 0.25, 0.0, 1.0)

	_draw_ring()

	var plate := Rect2(-22.0, -22.0, 44.0, 44.0)
	Palette.draw_rounded_rect(self, Rect2(plate.position + shadow * 0.6, plate.size), 6.0, Palette.SHADOW_COLOR)
	Palette.draw_rounded_rect(self, plate, 6.0, Palette.SHIP_PART_EDGE)
	Palette.draw_rounded_rect(self, Rect2(-22.0, -22.0, 42.0, 41.0), 6.0, Palette.SHIP_PART)

	# Bronze hexagonal cradle.
	draw_colored_polygon(_hexagon(17.0, shadow * 0.3), Color(0.0, 0.0, 0.0, 0.22))
	draw_colored_polygon(_hexagon(17.0), BRONZE_DARK)
	draw_colored_polygon(_hexagon(15.5, Vector2(-0.6, -0.6)), BRONZE)
	draw_colored_polygon(_hexagon(13.0), Palette.MECH)

	# Breathing glow and the green crystal.
	draw_circle(Vector2.ZERO, 9.0 + 3.0 * breath + 4.0 * flash, Color(HEAL, 0.16 + 0.12 * breath + 0.3 * flash))
	var size := 1.0 + 0.06 * breath + 0.18 * flash
	var half_w := 6.4 * size
	var half_h := 9.6 * size
	var top := Vector2(0.0, -half_h)
	var right := Vector2(half_w, 0.0)
	var bottom := Vector2(0.0, half_h)
	var left := Vector2(-half_w, 0.0)
	draw_colored_polygon(PackedVector2Array([top, right, bottom, left]), HEAL_DARK)
	draw_colored_polygon(PackedVector2Array([top, right, Vector2.ZERO, left]), HEAL.lerp(HEAL_LIGHT, flash))
	draw_colored_polygon(PackedVector2Array([top, Vector2(half_w * 0.45, -half_h * 0.2), Vector2.ZERO]), Color(HEAL_LIGHT, 0.85))


## Mint ring sweeping out to the healing radius after each pulse.
func _draw_ring() -> void:
	if _ring_age >= RING_TIME:
		return
	var k := _ring_age / RING_TIME
	var eased := 1.0 - pow(1.0 - k, 3.0)
	var radius := lerpf(14.0, maxf(get_effective_healing_radius(), 14.0), eased)
	var fade := (1.0 - k) * _ring_strength
	draw_circle(Vector2.ZERO, radius, Color(HEAL, 0.10 * fade))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 72, Color(HEAL, 0.35 * fade), 7.0 * (1.0 - k) + 1.0)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 72, Color(HEAL_LIGHT, 0.9 * fade), 2.2 * (1.0 - k) + 0.6)


func _hexagon(radius: float, offset: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(6):
		points.append(offset + Vector2.RIGHT.rotated(PI / 6.0 + TAU * float(index) / 6.0) * radius)
	return points
