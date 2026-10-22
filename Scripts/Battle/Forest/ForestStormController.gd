class_name ForestStormController
extends CanvasLayer

## Rain is always active on the forest planet. Each storm REGROWS a tree on
## every empty spot a treant left (user design; spots dug out by dwarves stay
## gone). The storm spawns no enemies itself: the regrown trees are standing
## again, so the next waves' treants can tear out of them once more.
signal storm_warning(seconds_until_storm: float)
## `respawned` is the number of trees regrown by this storm.
signal storm_started(respawned: int)
signal storm_ended
signal respawns_finished

@export_range(10.0, 600.0, 1.0) var storm_interval: float = 90.0
@export_range(0.0, 30.0, 0.5) var warning_duration: float = 6.0
@export_range(1.0, 60.0, 0.5) var storm_duration: float = 12.0
@export_range(0.1, 3.0, 0.1) var respawn_spread_duration: float = 0.8
@export_range(1, 32, 1) var maximum_respawns_per_frame: int = 4

var battle: Node2D
var field: Battlefield
var ship: Ship
var enemies: Node2D
var wave_manager: WaveManager
var _time_until_storm: float = 90.0
var _storm_left: float = 0.0
var _warning_sent: bool = false
## Kept for compatibility: storms no longer spawn enemies (always 0).
var total_storm_respawns: int = 0
## Trees regrown by storms this battle.
var total_storm_regrown: int = 0
var rain_view: Control
var storm_label: Label
var _respawn_queue: Array[Dictionary] = []
var _respawn_cursor: int = 0
var _respawn_elapsed: float = 0.0

class RainView extends Control:
	var heavy: bool = false
	var clock: float = 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	func _process(delta: float) -> void:
		clock += delta
		queue_redraw()
	static func _rand(n: float) -> float:
		return fposmod(sin(n * 12.9898 + 4.1414) * 43758.5453, 1.0)

	## Rain style 1 (user pick): thin slanted streaks, splash rings on the
	## ground and a slightly cool tint; the storm is denser, faster, darker.
	func _draw() -> void:
		var w := maxf(size.x, 1.0)
		var h := maxf(size.y, 1.0)
		var k := 1.0 if heavy else 0.0
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.42, 0.54, 0.63, 0.08).lerp(Color(0.10, 0.15, 0.20, 0.24), k))
		# Every drop lives a short random cycle and reappears somewhere new, with
		# its own length, angle and brightness, so no columns or lattice show.
		var streaks := int(lerpf(110.0, 220.0, k) * w * h / (1600.0 * 900.0))
		var slant := lerpf(0.3, 0.42, k)
		for index in range(streaks):
			var seed := float(index) * 1.618
			var life := 0.35 + 0.3 * _rand(seed)
			var local := clock + _rand(seed + 1.0) * life
			var cycle := floorf(local / life)
			var t := fposmod(local, life) / life
			var n := seed * 7.0 + cycle * 13.0
			var near := _rand(n + 5.0)
			var length := lerpf(8.0, 22.0, near) * (1.0 + 0.4 * k)
			var fall := lerpf(90.0, 260.0, near) * (1.0 + 0.5 * k)
			var tilt := slant + (_rand(n + 6.0) - 0.5) * 0.12
			var start := Vector2(_rand(n + 2.0) * (w + 160.0) - 80.0, _rand(n + 3.0) * (h + 120.0) - 160.0)
			var head := start + Vector2(tilt, 1.0) * fall * t
			var alpha := lerpf(0.12, 0.38, near) * sin(PI * t) * (1.0 + 0.3 * k)
			draw_line(head, head - Vector2(tilt, 1.0) * length, Color(0.85, 0.91, 0.96, alpha), lerpf(1.0, 1.7, near))
		var splashes := int(lerpf(60.0, 100.0, k) * w * h / (1600.0 * 900.0))
		for index in range(splashes):
			var seed := float(index) + 0.5
			var phase := fposmod(clock * (1.6 + 0.8 * k) + fposmod(seed * 0.371, 1.0), 1.0)
			# Each ring lands somewhere new every cycle.
			var cycle := floorf(clock * (1.6 + 0.8 * k) + fposmod(seed * 0.371, 1.0))
			var at := Vector2(_rand(seed * 3.1 + cycle * 1.7) * w, _rand(seed * 5.3 + cycle * 2.9) * h)
			draw_arc(at, 2.0 + 9.0 * phase, 0.0, TAU, 14, Color(0.85, 0.91, 0.96, 0.5 * (1.0 - phase)), 1.3)


func _ready() -> void:
	layer = 1
	_time_until_storm = storm_interval
	rain_view = RainView.new()
	rain_view.name = "RainView"
	add_child(rain_view)
	storm_label = Label.new()
	storm_label.name = "StormStatus"
	storm_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	storm_label.offset_left = -120.0
	storm_label.offset_right = 120.0
	storm_label.offset_top = 12.0
	storm_label.offset_bottom = 34.0
	storm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	storm_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	storm_label.add_theme_color_override("font_color", Color("E6F1D7"))
	storm_label.hide()
	add_child(storm_label)

func _process(delta: float) -> void:
	if not is_instance_valid(battle) or battle.get("_battle_ended") == true:
		stop_storms()
		return
	_advance_respawns(delta)
	if not is_processing():
		return
	if _storm_left > 0.0:
		_storm_left = maxf(0.0, _storm_left - delta)
		if _storm_left <= 0.0:
			rain_view.set("heavy", false)
			storm_label.hide()
			storm_ended.emit()
		return
	_time_until_storm -= delta
	if not _warning_sent and _time_until_storm <= warning_duration:
		_warning_sent = true
		storm_warning.emit(maxf(_time_until_storm, 0.0))
	if _warning_sent:
		storm_label.text = tr("STORM IN %d") % ceili(maxf(_time_until_storm, 0.0))
		storm_label.show()
	if _time_until_storm <= 0.0:
		start_storm()

## Regrows every empty spot (staggered over respawn_spread_duration so the
## forest visibly sprouts back). Returns how many trees regrow.
func start_storm() -> int:
	if not is_instance_valid(battle) or battle.get("_battle_ended") == true:
		return 0
	if not is_instance_valid(field) or not is_instance_valid(field.forest_terrain):
		return 0
	var spots := field.forest_terrain.used_active_trees()
	for tree in spots:
		tree.regrow(randf() * respawn_spread_duration)
	var count := spots.size()
	total_storm_regrown += count
	_storm_left = storm_duration
	_time_until_storm = storm_interval
	_warning_sent = false
	rain_view.set("heavy", true)
	storm_label.text = tr("STORM")
	storm_label.show()
	storm_started.emit(count)
	respawns_finished.emit()
	return count

## Storms queue no enemy spawns any more (kept for callers / tests).
func get_pending_respawn_count() -> int:
	return 0

func _advance_respawns(_delta: float) -> void:
	pass

func _update_pending_count() -> void:
	if is_instance_valid(wave_manager):
		wave_manager.set_pending_external_spawns(&"forest_storm", get_pending_respawn_count())

func stop_storms() -> void:
	set_process(false)
	_respawn_queue.clear()
	_respawn_cursor = 0
	_update_pending_count()
	if is_instance_valid(rain_view):
		rain_view.set("heavy", false)
	if is_instance_valid(storm_label):
		storm_label.hide()
