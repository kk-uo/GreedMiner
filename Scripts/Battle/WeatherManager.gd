class_name WeatherManager
extends Node

## Sources are independent; the highest-priority active contribution wins.
signal weather_changed(weather: int)
signal blood_moon_started
signal blood_moon_ended
signal lightning_triggered
signal ship_freeze_changed(frozen: bool)
signal boss_entrance_started(duration: float)
## QTE while the ship is frozen: every click chips the ice (remaining seconds).
signal freeze_qte_clicked(remaining: float)
## Seconds taken off the freeze per click.
const FREEZE_CLICK_REDUCTION: float = 0.5
enum Weather { NONE, BLIZZARD_NORMAL, BLIZZARD_BOSS }
@export var normal_speed_bonus: float = 10.0
var current_weather: int = Weather.NONE
var _sources: Dictionary = {}
var _freeze_left: float = 0.0
var _shake_left: float = 0.0
var _shake_elapsed: float = 0.0
var _camera: Camera2D
var _original_offset := Vector2.ZERO
var _overlay: ColorRect
## Snow, fog and gusts under the HUD (design 2; the boss blizzard adds 3).
const BlizzardOverlay := preload("res://Scripts/VFX/BlizzardOverlay.gd")
var _blizzard: Control
## Graveyard Planet lightning (v2) and blood moon (v3), created on first use.
## Visual only for now: nothing schedules them and they change no stats.
const GraveyardWeatherOverlay := preload("res://Scripts/VFX/GraveyardWeatherOverlay.gd")
var _graveyard_fx: Control
var blood_moon_active: bool = false
@export var blood_moon_speed_amount: float = 10.0
## Additional damage reduction, applied after an enemy's own defenses.
@export_range(0.0, 1.0, 0.01) var blood_moon_damage_reduction: float = 0.5

func _ready() -> void:
	add_to_group("battle_weather_manager")
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.65, 0.85, 1.0, 0.12)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.hide()
	layer.add_child(_overlay)
	# Layer 1 and earlier in the scene than BattleUI, so it draws under the HUD.
	var snow_layer := CanvasLayer.new()
	snow_layer.layer = 1
	add_child(snow_layer)
	_blizzard = BlizzardOverlay.new()
	_blizzard.name = "Blizzard"
	snow_layer.add_child(_blizzard)

func _process(delta: float) -> void:
	if _freeze_left > 0.0:
		_freeze_left = maxf(0.0, _freeze_left - delta)
		_update_overlay()
		if _freeze_left <= 0.0:
			ship_freeze_changed.emit(false)
	if _shake_left > 0.0:
		_shake_left = maxf(0.0, _shake_left - delta)
		_shake_elapsed += delta
		if is_instance_valid(_camera):
			_camera.offset = _original_offset + Vector2(sin(_shake_elapsed * 35.0), cos(_shake_elapsed * 41.0)) * 3.0 if _shake_left > 0.0 else _original_offset

func _input(event: InputEvent) -> void:
	if is_input_frozen() and (event is InputEventMouse or event is InputEventKey or event is InputEventScreenTouch or event is InputEventScreenDrag):
		var click: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
				or (event is InputEventScreenTouch and event.pressed)
		if click:
			qte_click()
		get_viewport().set_input_as_handled()

## One QTE click while frozen: takes FREEZE_CLICK_REDUCTION off the freeze.
func qte_click() -> void:
	if not is_input_frozen():
		return
	_freeze_left = maxf(0.0, _freeze_left - FREEZE_CLICK_REDUCTION)
	freeze_qte_clicked.emit(_freeze_left)
	if _freeze_left <= 0.0:
		_update_overlay()
		ship_freeze_changed.emit(false)

func freeze_input(duration: float) -> void:
	var was_frozen := is_input_frozen()
	_freeze_left = maxf(_freeze_left, duration)
	_update_overlay()
	if not was_frozen and is_input_frozen():
		ship_freeze_changed.emit(true)

func is_input_frozen() -> bool:
	return _freeze_left > 0.0

## Seconds left on the current ship freeze (0 when not frozen). Used by the
## frozen-ship visual's countdown.
func get_freeze_remaining() -> float:
	return _freeze_left

func clear_transient_effects() -> void:
	var was_frozen := is_input_frozen()
	_freeze_left = 0.0
	_shake_left = 0.0
	if is_instance_valid(_camera):
		_camera.offset = _original_offset
	_update_overlay()
	if was_frozen:
		ship_freeze_changed.emit(false)

func start_entrance_shake(duration: float) -> void:
	boss_entrance_started.emit(duration)
	_camera = get_viewport().get_camera_2d()
	if is_instance_valid(_camera):
		_original_offset = _camera.offset
	_shake_elapsed = 0.0
	_shake_left = maxf(duration, 0.0)

func _update_overlay() -> void:
	if not is_instance_valid(_overlay):
		return
	# The blizzard itself is drawn by BlizzardOverlay; this tint now only marks
	# the frozen-input state.
	_overlay.visible = is_input_frozen()
	if is_instance_valid(_blizzard):
		_blizzard.level = 2 if current_weather == Weather.BLIZZARD_BOSS else (1 if current_weather == Weather.BLIZZARD_NORMAL else 0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP if is_input_frozen() else Control.MOUSE_FILTER_IGNORE

func add_source(source_id: int, weather: int) -> void:
	_sources[source_id] = weather
	_refresh()

func remove_source(source_id: int) -> void:
	_sources.erase(source_id)
	_refresh()

func remove_source_after(source_id: int, delay: float) -> void:
	await get_tree().create_timer(maxf(delay, 0.0)).timeout
	if is_inside_tree():
		remove_source(source_id)

func _refresh() -> void:
	var next: int = Weather.NONE
	for value in _sources.values():
		next = maxi(next, int(value))
	if current_weather != next:
		current_weather = next
		_update_overlay()
		weather_changed.emit(current_weather)

func speed_bonus() -> float:
	return normal_speed_bonus if current_weather == Weather.BLIZZARD_NORMAL else 0.0


# ==========================================
# Graveyard Planet weather (presentation only)
# ==========================================

## The graveyard weather overlay (lightning + blood moon), created on demand
## under the HUD. Connect its blackout_started / blackout_ended signals to
## spawn things out of the graves during the dark.
func get_graveyard_weather() -> Control:
	if not is_instance_valid(_graveyard_fx):
		var layer := CanvasLayer.new()
		layer.layer = 1
		layer.name = "GraveyardWeather"
		add_child(layer)
		_graveyard_fx = GraveyardWeatherOverlay.new()
		_graveyard_fx.name = "GraveyardWeatherOverlay"
		layer.add_child(_graveyard_fx)
	return _graveyard_fx


## Lightning strike: flash, ~2.45 s of complete darkness, reveal flash.
func play_graveyard_lightning() -> void:
	lightning_triggered.emit()
	get_graveyard_weather().call("play_lightning")


## Blood moon on/off: red regrade, falling ash, heartbeat edge, enemy auras.
func set_blood_moon(active: bool) -> void:
	if blood_moon_active == active:
		return
	blood_moon_active = active
	get_graveyard_weather().set("blood_moon", active)
	if active:
		blood_moon_started.emit()
	else:
		blood_moon_ended.emit()

func blood_moon_speed_bonus() -> float:
	return blood_moon_speed_amount if blood_moon_active else 0.0
