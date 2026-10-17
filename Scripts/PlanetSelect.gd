class_name PlanetSelect
extends Control

## Controls the data-driven planet carousel and scene navigation.

const BASE_SCENE_PATH: String = "res://Scenes/base_main.tscn"
const BATTLE_SCENE_PATH: String = "res://Scenes/BattleMain.tscn"

const PLANETS: Array[Dictionary] = [
	{
		"id": &"rocky_planet",
		"name": "ROCKY PLANET",
		"description": "A mineral-rich rocky world inhabited by hostile stone creatures.",
		"unlocked": true,
		"enemies": ["Little Rock", "Rock Golem"],
		"theme": &"rocky",
	},
	{
		"id": &"frozen_planet",
		"name": "FROZEN PLANET",
		"description": "An unexplored frozen world.",
		"unlocked": false,
		"enemies": [],
		"theme": &"frozen",
	},
	{
		"id": &"volcanic_planet",
		"name": "VOLCANIC PLANET",
		"description": "An unstable volcanic world.",
		"unlocked": false,
		"enemies": [],
		"theme": &"volcanic",
	},
]

const PLANET_VISUAL_SIZE: Vector2 = Vector2(320.0, 320.0)
const CAROUSEL_DURATION: float = 0.42

@onready var planet_layer: Control = $CarouselArea/PlanetLayer
@onready var left_button: Button = $CarouselArea/LeftButton
@onready var right_button: Button = $CarouselArea/RightButton
@onready var planet_name_label: Label = $InfoPanel/MarginContainer/InfoLayout/TitleRow/PlanetName
@onready var status_label: Label = $InfoPanel/MarginContainer/InfoLayout/TitleRow/Status
@onready var description_label: Label = $InfoPanel/MarginContainer/InfoLayout/Description
@onready var enemies_label: Label = $InfoPanel/MarginContainer/InfoLayout/KnownEnemies
@onready var position_label: Label = $CarouselArea/PositionLabel
@onready var back_button: Button = $InfoPanel/MarginContainer/InfoLayout/Actions/BackButton
@onready var deploy_button: Button = $InfoPanel/MarginContainer/InfoLayout/Actions/DeployButton
@onready var transition_overlay: ColorRect = $TransitionOverlay

var selected_index: int = 0
var _planet_visuals: Array[PlanetVisual] = []
var _carousel_tween: Tween
var _transitioning: bool = false
var _background_time: float = 0.0


func _ready() -> void:
	_build_planet_visuals()
	_connect_once(left_button.pressed, _on_left_pressed)
	_connect_once(right_button.pressed, _on_right_pressed)
	_connect_once(back_button.pressed, _on_back_pressed)
	_connect_once(deploy_button.pressed, _on_deploy_pressed)
	_connect_once(get_viewport().size_changed, _on_viewport_size_changed)

	_update_planet_information()
	call_deferred("_layout_planets", false)
	_fade_in()


func _process(delta: float) -> void:
	_background_time = fmod(_background_time + delta, TAU * 100.0)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _transitioning:
		return

	if event.is_action_pressed("ui_left"):
		_on_left_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_on_right_pressed()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_on_left_pressed()
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_on_right_pressed()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("14100D"), true)

	# Style A: a few flat, low-contrast discs instead of glowing nebulae.
	draw_circle(size * Vector2(0.18, 0.28), size.y * 0.34, Color(Palette.UI_PANEL_RAISED, 0.55))
	draw_circle(size * Vector2(0.82, 0.24), size.y * 0.28, Color(Palette.UI_PANEL_RAISED, 0.4))
	draw_circle(size * Vector2(0.54, 0.62), size.y * 0.42, Color(Palette.UI_PANEL, 0.6))

	var stars := [
		Vector2(0.04, 0.12), Vector2(0.09, 0.37), Vector2(0.13, 0.68),
		Vector2(0.18, 0.19), Vector2(0.23, 0.52), Vector2(0.27, 0.09),
		Vector2(0.31, 0.76), Vector2(0.36, 0.26), Vector2(0.41, 0.58),
		Vector2(0.46, 0.14), Vector2(0.51, 0.43), Vector2(0.56, 0.08),
		Vector2(0.61, 0.72), Vector2(0.66, 0.31), Vector2(0.71, 0.12),
		Vector2(0.76, 0.57), Vector2(0.81, 0.08), Vector2(0.86, 0.41),
		Vector2(0.91, 0.67), Vector2(0.95, 0.20), Vector2(0.07, 0.82),
		Vector2(0.20, 0.88), Vector2(0.39, 0.87), Vector2(0.58, 0.83),
		Vector2(0.78, 0.88), Vector2(0.93, 0.79),
	]
	for star_index in range(stars.size()):
		var flicker := 0.58 + sin(_background_time * 1.7 + star_index * 1.91) * 0.22
		var radius := 1.0 + float(star_index % 3) * 0.55
		draw_circle(stars[star_index] * size, radius, Color(Palette.UI_TEXT, flicker * 0.8))

	# Orbital scanner rings visually connect the three destinations.
	var orbit_center := Vector2(size.x * 0.5, size.y * 0.39)
	draw_arc(orbit_center, 158.0, 0.0, TAU, 120, Color(Palette.UI_MUTED, 0.18), 2.0)
	draw_arc(orbit_center, 214.0, 0.0, TAU, 140, Color(Palette.UI_MUTED, 0.12), 2.0)
	draw_line(Vector2(size.x * 0.12, orbit_center.y), Vector2(size.x * 0.88, orbit_center.y), Color(Palette.UI_MUTED, 0.10), 2.0)


func _build_planet_visuals() -> void:
	for child in planet_layer.get_children():
		child.queue_free()
	_planet_visuals.clear()

	for planet_index in range(PLANETS.size()):
		var visual := PlanetVisual.new()
		visual.name = "Planet_%s" % PLANETS[planet_index]["id"]
		visual.configure(PLANETS[planet_index], planet_index)
		visual.pressed.connect(_on_planet_pressed)
		planet_layer.add_child(visual)
		_planet_visuals.append(visual)


func _connect_once(source_signal: Signal, callback: Callable) -> void:
	if not source_signal.is_connected(callback):
		source_signal.connect(callback)


func _on_left_pressed() -> void:
	_select_planet(posmod(selected_index - 1, PLANETS.size()))


func _on_right_pressed() -> void:
	_select_planet(posmod(selected_index + 1, PLANETS.size()))


func _on_planet_pressed(planet_index: int) -> void:
	_select_planet(planet_index)


func _select_planet(planet_index: int) -> void:
	if _transitioning or planet_index == selected_index:
		return

	selected_index = clampi(planet_index, 0, PLANETS.size() - 1)
	_update_planet_information()
	_layout_planets(true)


func _layout_planets(animated: bool = true) -> void:
	if _planet_visuals.is_empty():
		return

	if _carousel_tween != null and _carousel_tween.is_valid():
		_carousel_tween.kill()

	var center := Vector2(size.x * 0.5, size.y * 0.39)
	var horizontal_spacing := minf(size.x * 0.285, 455.0)
	var planet_count := _planet_visuals.size()

	if animated:
		_carousel_tween = create_tween()
		_carousel_tween.set_parallel(true)
		_carousel_tween.set_trans(Tween.TRANS_QUINT)
		_carousel_tween.set_ease(Tween.EASE_OUT)

	for planet_index in range(planet_count):
		var visual := _planet_visuals[planet_index]
		var offset := planet_index - selected_index
		if offset > planet_count / 2:
			offset -= planet_count
		elif offset < -planet_count / 2:
			offset += planet_count

		var is_selected := offset == 0
		var target_center := center + Vector2(float(offset) * horizontal_spacing, 0.0)
		var target_position := target_center - PLANET_VISUAL_SIZE * 0.5
		var target_scale := Vector2.ONE if is_selected else Vector2.ONE * 0.62
		var target_color := Color.WHITE if is_selected else Color(0.72, 0.68, 0.62, 0.75)
		var target_selection := 1.0 if is_selected else 0.0
		visual.z_index = 5 if is_selected else 1

		if animated:
			_carousel_tween.tween_property(visual, "position", target_position, CAROUSEL_DURATION)
			_carousel_tween.tween_property(visual, "scale", target_scale, CAROUSEL_DURATION)
			_carousel_tween.tween_property(visual, "modulate", target_color, CAROUSEL_DURATION)
			_carousel_tween.tween_property(visual, "selection_amount", target_selection, CAROUSEL_DURATION)
		else:
			visual.position = target_position
			visual.scale = target_scale
			visual.modulate = target_color
			visual.selection_amount = target_selection


func _update_planet_information() -> void:
	var planet := PLANETS[selected_index]
	var is_unlocked := bool(planet["unlocked"])
	planet_name_label.text = String(planet["name"])
	description_label.text = String(planet["description"])
	status_label.text = "UNLOCKED" if is_unlocked else "LOCKED"
	status_label.modulate = Palette.ACCENT if is_unlocked else Palette.UI_MUTED

	var enemies: Array = planet["enemies"]
	if enemies.is_empty():
		enemies_label.text = "KNOWN THREATS  //  UNKNOWN"
	else:
		enemies_label.text = "KNOWN THREATS  //  %s" % ", ".join(enemies)

	deploy_button.disabled = not is_unlocked
	deploy_button.text = "DEPLOY" if is_unlocked else "DESTINATION LOCKED"
	position_label.text = _build_position_indicator()


func _build_position_indicator() -> String:
	var indicator := ""
	for planet_index in range(PLANETS.size()):
		indicator += "◆" if planet_index == selected_index else "◇"
		if planet_index < PLANETS.size() - 1:
			indicator += "   "
	return indicator


func _on_viewport_size_changed() -> void:
	call_deferred("_layout_planets", false)


func _on_back_pressed() -> void:
	await _transition_to_scene(BASE_SCENE_PATH)


func _on_deploy_pressed() -> void:
	var selected_planet := PLANETS[selected_index]
	if not bool(selected_planet["unlocked"]):
		return

	# Only Rocky Planet is currently playable. A future PlanetManager can use
	# selected_planet["id"] here before BattleMain is loaded.
	ResourceManager.start_new_mission()
	await _transition_to_scene(BATTLE_SCENE_PATH)


func _fade_in() -> void:
	transition_overlay.color.a = 1.0
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(transition_overlay, "color:a", 0.0, 0.35)


func _transition_to_scene(scene_path: String) -> void:
	if _transitioning:
		return

	_transitioning = true
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(transition_overlay, "color:a", 1.0, 0.24)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)
