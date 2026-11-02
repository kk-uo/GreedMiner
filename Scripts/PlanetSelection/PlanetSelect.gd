class_name PlanetSelect
extends Control

## Controls the data-driven planet carousel and scene navigation.

const BASE_SCENE_PATH: String = "res://Scenes/Base/base_main.tscn"
const BATTLE_SCENE_PATH: String = "res://Scenes/Battle/BattleMain.tscn"

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
		"id": &"goblin_planet",
		"name": "VERDANT PLANET",
		"description": "Looks like a lush, overgrown jungle world... Wait, no! It's crawling with goblins!",
		"unlocked": true,
		"enemies": ["Goblins"],
		"theme": &"jungle",
		# Ore spent once to pinpoint the planet's coordinates ("precise locate").
		"locate_cost": 250,
	},
	{
		"id": &"frozen_planet",
		"name": "FROZEN PLANET",
		"description": "A frozen world inhabited by snow monsters.",
		"unlocked": true,
		"playable": true,
		"locate_cost": 500,
		"enemies": ["Snow Monster", "Mega Monster"],
		"theme": &"frozen",
		# Frozen and Volcanic share one star-map slot as a twin system that
		# orbits itself; the player clicks either planet (Claude sync 88).
		"pair": &"fire_ice",
	},
	{
		"id": &"volcanic_planet",
		"name": "VOLCANIC PLANET",
		"description": "An unstable volcanic world.",
		"pair": &"fire_ice",
		# Lava Planet uses this existing Volcanic Planet identity. Its eleventh
		# wave intentionally stops at the reserved future-boss integration point.
		"unlocked": true,
		"playable": true,
		"locate_cost": 1000,
		"enemies": ["Demon", "Hellhunter", "Big Demon", "Imp"],
		"theme": &"volcanic",
	},
	{
		"id": &"graveyard_planet",
		"name": "GRAVEYARD PLANET",
		"description": "Endless fields of tombstones where the dead refuse to rest... yet beneath them lie the richest biomass deposits ever charted.",
		# The encounter uses the existing locate cost and progression flow.
		"unlocked": true,
		"playable": true,
		"locate_cost": 2000,
		"enemies": ["Skeleton", "Zombie", "Werewolf", "Vampire", "Giant Frank"],
		"theme": &"graveyard",
	},
	{
		"id": &"tree_planet",
		"name": "TREE PLANET",
		"description": "A rain-soaked forest where cutting trees prevents their defenders from returning in storms.",
		"unlocked": true,
		"playable": true,
		"enemies": ["Fairy", "Treant", "Big Treant", "Chainsaw Spaceship Treant"],
		"theme": &"forest",
	},
	{
		"id": &"dragon_nest_planet",
		"name": "DRAGON NEST",
		"description": "A low-density dragon stronghold with three optional treasure hoards and an Ancient Dragon.",
		"unlocked": true,
		"playable": true,
		"enemies": ["Kobold", "Nest Lizard", "Young Dragon", "Greater Dragon", "Ancient Dragon"],
		"theme": &"dragon_nest",
	},
]

const PLANET_VISUAL_SIZE: Vector2 = Vector2(320.0, 320.0)
const CAROUSEL_DURATION: float = 0.42
## Twin-system slot: the two planets orbit their shared slot centre.
const TWIN_ORBIT := Vector2(122.0, 34.0)
const TWIN_SCALE: float = 0.62
const TWIN_SPIN: float = 0.45

## Testable transition target; normal gameplay keeps the existing battle scene.
@export_file("*.tscn") var battle_scene_path: String = BATTLE_SCENE_PATH

@onready var planet_layer: Control = $CarouselArea/PlanetLayer
@onready var left_button: Button = $CarouselArea/LeftButton
@onready var right_button: Button = $CarouselArea/RightButton
@onready var planet_name_label: Label = $InfoPanel/MarginContainer/InfoLayout/TitleRow/PlanetName
@onready var status_label: Label = $InfoPanel/MarginContainer/InfoLayout/TitleRow/Status
@onready var description_label: Label = $InfoPanel/MarginContainer/InfoLayout/Description
@onready var enemies_label: Label = $InfoPanel/MarginContainer/InfoLayout/KnownEnemies
@onready var energy_requirements_label: Label = $InfoPanel/MarginContainer/InfoLayout/EnergyRequirements
@onready var position_label: Label = $CarouselArea/PositionLabel
@onready var back_button: Button = $InfoPanel/MarginContainer/InfoLayout/Actions/BackButton
@onready var deploy_button: Button = $InfoPanel/MarginContainer/InfoLayout/Actions/DeployButton
@onready var transition_overlay: ColorRect = $TransitionOverlay

var selected_index: int = 0
var _planet_visuals: Array[PlanetVisual] = []
var _star_map_planets: Array[Dictionary] = []
var _carousel_tween: Tween
## Carousel slots: each lists the visible-planet indices it holds (one, or
## two for a twin system). _scroll is the (fractional) slot in the centre.
var _slots: Array = []
var _planet_slot: Array[int] = []
var _pair_choice: Dictionary = {}
var _scroll: float = 0.0
var _orbit_time: float = 0.0
var _transitioning: bool = false
var _background_time: float = 0.0


func _ready() -> void:
	# Reopen the star map on the destination the player most recently deployed
	# to. Hidden destinations safely fall back to Rocky without changing the
	# saved expedition ID or any completion/location data.
	_star_map_planets = get_visible_planets()
	_build_slots()
	selected_index = get_visible_planet_index(ResourceManager.current_expedition_planet_id)
	_pair_choice[_planet_slot[selected_index]] = selected_index
	_build_planet_visuals()
	_connect_once(left_button.pressed, _on_left_pressed)
	_connect_once(right_button.pressed, _on_right_pressed)
	_connect_once(back_button.pressed, _on_back_pressed)
	_connect_once(deploy_button.pressed, _on_deploy_pressed)
	_connect_once(ResourceManager.stored_ore_changed, _on_stored_ore_changed)
	_connect_once(get_viewport().size_changed, _on_viewport_size_changed)

	_update_planet_information()
	call_deferred("_layout_planets", false)
	_fade_in()


## Returns the carousel index for a stable planet ID. Unknown or removed IDs
## safely fall back to Rocky Planet at index zero.
static func get_planet_index(planet_id: StringName) -> int:
	for planet_index in range(PLANETS.size()):
		if StringName(PLANETS[planet_index].get("id", &"")) == planet_id:
			return planet_index
	return 0


## Player-facing list only. PLANETS remains the complete registry used by
## progression, developer commands, research dependencies, and tests.
static func get_visible_planets() -> Array[Dictionary]:
	var visible_planets: Array[Dictionary] = []
	for planet in PLANETS:
		if not bool(planet.get("hidden_from_star_map", false)):
			visible_planets.append(planet)
	return visible_planets


static func get_visible_planet_index(planet_id: StringName) -> int:
	var visible_planets := get_visible_planets()
	for planet_index in range(visible_planets.size()):
		if StringName(visible_planets[planet_index].get("id", &"")) == planet_id:
			return planet_index
	return 0


## Groups visible planets into carousel slots (twins by their "pair" id).
func _build_slots() -> void:
	_slots.clear()
	_planet_slot.clear()
	var pair_slot: Dictionary = {}
	for planet_index in range(_star_map_planets.size()):
		var pair := StringName(_star_map_planets[planet_index].get("pair", &""))
		if pair != &"" and pair_slot.has(pair):
			var slot_index: int = pair_slot[pair]
			(_slots[slot_index] as Array).append(planet_index)
			_planet_slot.append(slot_index)
			continue
		if pair != &"":
			pair_slot[pair] = _slots.size()
		_planet_slot.append(_slots.size())
		_slots.append([planet_index])


func get_slot_count() -> int:
	return _slots.size()


## Visible-planet indices sharing the selected planet's slot (tests / UI).
func get_selected_slot_planets() -> Array:
	return _slots[_planet_slot[selected_index]] if selected_index < _planet_slot.size() else []


func _process(delta: float) -> void:
	_background_time = fmod(_background_time + delta, TAU * 100.0)
	_orbit_time = fmod(_orbit_time + delta * TWIN_SPIN, TAU)
	_apply_layout()
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
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		# Switch between the two planets of a twin system.
		var twins: Array = get_selected_slot_planets()
		if twins.size() > 1:
			_select_planet(int(twins[(twins.find(selected_index) + 1) % twins.size()]))
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

	# Twin systems: the shared orbit the two planets travel along.
	for slot_index in range(_slots.size()):
		if (_slots[slot_index] as Array).size() < 2:
			continue
		var pose := _slot_pose(slot_index)
		var ring := PackedVector2Array()
		for step in range(65):
			var a := TAU * float(step) / 64.0
			ring.append(pose["center"] + Vector2(cos(a) * TWIN_ORBIT.x, sin(a) * TWIN_ORBIT.y) * float(pose["scale"]))
		draw_polyline(ring, Color(Palette.ACCENT, 0.12 + 0.28 * float(pose["focus"])), 2.0)


func _build_planet_visuals() -> void:
	for child in planet_layer.get_children():
		child.queue_free()
	_planet_visuals.clear()

	for planet_index in range(_star_map_planets.size()):
		var visual := PlanetVisual.new()
		visual.name = "Planet_%s" % _star_map_planets[planet_index]["id"]
		visual.configure(_star_map_planets[planet_index], planet_index)
		visual.uncharted = not is_planet_located(_star_map_planets[planet_index])
		visual.pressed.connect(_on_planet_pressed)
		planet_layer.add_child(visual)
		_planet_visuals.append(visual)


func _connect_once(source_signal: Signal, callback: Callable) -> void:
	if not source_signal.is_connected(callback):
		source_signal.connect(callback)


func _on_left_pressed() -> void:
	_select_slot(posmod(_planet_slot[selected_index] - 1, _slots.size()))


func _on_right_pressed() -> void:
	_select_slot(posmod(_planet_slot[selected_index] + 1, _slots.size()))


## Moves to a slot; a twin system reopens on the planet last chosen there.
func _select_slot(slot_index: int) -> void:
	var planets: Array = _slots[slot_index]
	_select_planet(int(_pair_choice.get(slot_index, planets[0])))


func _on_planet_pressed(planet_index: int) -> void:
	_select_planet(planet_index)


func _select_planet(planet_index: int) -> void:
	if _transitioning or planet_index == selected_index:
		return

	selected_index = clampi(planet_index, 0, _star_map_planets.size() - 1)
	_pair_choice[_planet_slot[selected_index]] = selected_index
	_update_planet_information()
	_layout_planets(true)


## Scrolls the carousel so the selected planet's slot is centred. Poses are
## applied every frame by _apply_layout (twins keep orbiting).
func _layout_planets(animated: bool = true) -> void:
	if _planet_visuals.is_empty() or _slots.is_empty():
		return
	if _carousel_tween != null and _carousel_tween.is_valid():
		_carousel_tween.kill()
	var target := float(_planet_slot[selected_index])
	var count := float(_slots.size())
	var delta := wrapf(target - _scroll, -count * 0.5, count * 0.5)
	if animated and absf(delta) > 0.001:
		_carousel_tween = create_tween()
		_carousel_tween.set_trans(Tween.TRANS_QUINT)
		_carousel_tween.set_ease(Tween.EASE_OUT)
		_carousel_tween.tween_property(self, "_scroll", _scroll + delta, CAROUSEL_DURATION)
	else:
		_scroll = target
	_apply_layout()


## Where a slot sits now: centre, scale, and focus (1 when centred).
func _slot_pose(slot_index: int) -> Dictionary:
	var center := Vector2(size.x * 0.5, size.y * 0.39)
	var horizontal_spacing := minf(size.x * 0.285, 455.0)
	var count := float(_slots.size())
	var offset := wrapf(float(slot_index) - _scroll, -count * 0.5, count * 0.5)
	var focus := clampf(1.0 - absf(offset), 0.0, 1.0)
	return {
		"center": center + Vector2(offset * horizontal_spacing, 0.0),
		"scale": lerpf(0.62, 1.0, focus),
		"focus": focus,
	}


func _apply_layout() -> void:
	if _planet_visuals.is_empty() or _slots.is_empty():
		return
	var dim := Color(0.72, 0.68, 0.62, 0.75)
	for slot_index in range(_slots.size()):
		var planets: Array = _slots[slot_index]
		var pose := _slot_pose(slot_index)
		var focus: float = pose["focus"]
		var slot_scale: float = pose["scale"]
		var slot_center: Vector2 = pose["center"]
		var tint := dim.lerp(Color.WHITE, focus)
		if planets.size() == 1:
			var visual := _planet_visuals[int(planets[0])]
			visual.position = slot_center - PLANET_VISUAL_SIZE * 0.5
			visual.scale = Vector2.ONE * slot_scale
			visual.modulate = tint
			visual.selection_amount = focus
			visual.z_index = 5 if focus > 0.5 else 1
			continue
		var chosen := int(_pair_choice.get(slot_index, planets[0]))
		for twin in range(planets.size()):
			var planet_index := int(planets[twin])
			var visual := _planet_visuals[planet_index]
			var angle := _orbit_time + PI * float(twin)
			var depth := sin(angle)
			var at := slot_center + Vector2(cos(angle) * TWIN_ORBIT.x, depth * TWIN_ORBIT.y) * slot_scale
			var is_chosen := planet_index == chosen
			var twin_scale := slot_scale * TWIN_SCALE * (1.0 + 0.1 * depth) * (1.1 if is_chosen and focus > 0.5 else 1.0)
			visual.position = at - PLANET_VISUAL_SIZE * 0.5
			visual.scale = Vector2.ONE * twin_scale
			visual.modulate = tint if is_chosen else tint.lerp(dim, 0.45 * focus)
			visual.selection_amount = focus if is_chosen else 0.0
			visual.z_index = (6 if focus > 0.5 else 2) + (1 if depth > 0.0 else 0)


func _update_planet_information() -> void:
	var planet := _star_map_planets[selected_index]
	var profile := ShipEnergySystem.calculate_loadout_profile(ShipLoadout.installed_modules)
	var launch_status := evaluate_launch_requirements(planet, profile, ResourceManager.stored_ore)
	var is_unlocked := bool(launch_status.unlocked)
	var is_located := bool(launch_status.located)
	planet_name_label.text = tr(String(planet["name"]))
	description_label.text = tr(String(planet["description"]))
	if get_selected_slot_planets().size() > 1:
		description_label.text += "\n" + tr("FIRE & ICE TWINS  ·  CLICK A PLANET TO SWITCH CHALLENGE")
	var in_range := bool(launch_status.get("in_range", true))
	status_label.text = ("LOCATED" if is_located else "UNCHARTED") if is_unlocked else "LOCKED"
	if is_unlocked and not in_range:
		status_label.text = "OUT OF RANGE"
	status_label.modulate = Palette.ACCENT if is_unlocked and in_range and is_located else Palette.UI_MUTED

	var enemies: Array = planet["enemies"]
	if enemies.is_empty():
		enemies_label.text = "KNOWN THREATS  //  UNKNOWN"
	else:
		var translated_enemies: Array[String] = []
		for enemy in enemies:
			translated_enemies.append(tr(String(enemy)))
		enemies_label.text = tr("KNOWN THREATS  //  %s") % ", ".join(translated_enemies)

	energy_requirements_label.text = _format_location(launch_status)
	deploy_button.disabled = not bool(launch_status.eligible) and not bool(launch_status.can_locate)
	deploy_button.text = _get_deploy_button_text(launch_status)
	position_label.text = _build_position_indicator()


static func get_locate_cost(planet: Dictionary) -> int:
	return maxi(int(planet.get("locate_cost", 0)), 0)


static func is_planet_located(planet: Dictionary) -> bool:
	return WeaponUnlockManager.is_planet_located(StringName(planet["id"]), get_locate_cost(planet))


## Pure eligibility query used by the UI and automated tests.
## A planet must be unlocked (not "coming soon"), within range (planets gated
## by research: Long-Range Cells for Verdant / Frozen, Air Conditioning for
## Frozen / Volcanic), located with ore,
## and the loadout must be operational (an Energy Module and enough power).
static func evaluate_launch_requirements(
	planet: Dictionary,
	energy_profile: Dictionary,
	stored_ore: float
) -> Dictionary:
	var unlocked := bool(planet.get("unlocked", false))
	var playable := bool(planet.get("playable", true))
	var cost := get_locate_cost(planet)
	var located := is_planet_located(planet)
	var loadout_valid := ShipEnergySystem.is_profile_operational(energy_profile)
	var planet_id := StringName(planet.get("id", &""))
	var range_research := ResearchManager.get_planet_access_research(planet_id)
	var in_range := ResearchManager.is_planet_in_range(planet_id)
	var range_definition := ResearchManager.get_definition(range_research) if not range_research.is_empty() else null
	return {
		"unlocked": unlocked,
		"in_range": in_range,
		"range_research": range_research,
		"range_research_name": range_definition.display_name if range_definition != null else "",
		"range_research_category": String(range_definition.category_id).to_upper() if range_definition != null else "",
		"playable": playable,
		"located": located,
		"locate_cost": cost,
		"can_locate": unlocked and in_range and not located and stored_ore >= float(cost),
		"missing_ore": maxi(cost - floori(stored_ore), 0) if not located else 0,
		"loadout_valid": loadout_valid,
		"eligible": unlocked and in_range and located and playable and loadout_valid,
	}


func _format_location(status: Dictionary) -> String:
	if not bool(status.unlocked):
		return "COORDINATES  //  OUT OF RANGE"
	if not bool(status.get("in_range", true)):
		return tr("OUT OF RANGE  //  RESEARCH %s IN THE LABORATORY (%s)") % [tr(String(status.range_research_name).to_upper()), tr(String(status.get("range_research_category", "")))]
	if bool(status.located):
		return "COORDINATES  //  LOCKED ON"
	return tr("COORDINATES  //  UNKNOWN   ·   PRECISE LOCATE COSTS %d ORE") % int(status.locate_cost)


func _get_deploy_button_text(status: Dictionary) -> String:
	if not bool(status.unlocked):
		return "DESTINATION LOCKED"
	if not bool(status.get("in_range", true)):
		return tr("NEED %s") % tr(String(status.range_research_name).to_upper())
	if not bool(status.located):
		if bool(status.can_locate):
			return tr("PRECISE LOCATE  ·  ◆ %d") % int(status.locate_cost)
		return tr("NEED ◆ %d ORE TO LOCATE") % int(status.locate_cost)
	if not bool(status.playable):
		return "WAVES COMING SOON"
	if not bool(status.loadout_valid):
		return "INVALID LOADOUT"
	return "DEPLOY"


func _build_position_indicator() -> String:
	var indicator := ""
	var current := _planet_slot[selected_index] if selected_index < _planet_slot.size() else 0
	for slot_index in range(_slots.size()):
		indicator += "◆" if slot_index == current else "◇"
		if slot_index < _slots.size() - 1:
			indicator += "   "
	return indicator


func _on_viewport_size_changed() -> void:
	call_deferred("_layout_planets", false)


func _on_stored_ore_changed(_amount: float) -> void:
	_update_planet_information()


func _on_back_pressed() -> void:
	await _transition_to_scene(BASE_SCENE_PATH)


func _on_deploy_pressed() -> void:
	var selected_planet := _star_map_planets[selected_index]
	var profile := ShipEnergySystem.calculate_loadout_profile(ShipLoadout.installed_modules)
	var launch_status := evaluate_launch_requirements(selected_planet, profile, ResourceManager.stored_ore)
	# First press on an uncharted planet buys its coordinates.
	if bool(launch_status.can_locate):
		locate_selected_planet()
		return
	if not bool(launch_status.eligible):
		_update_planet_information()
		return

	var previous_planet_id := ResourceManager.current_expedition_planet_id
	ResourceManager.set_current_expedition_planet(StringName(selected_planet["id"]))
	ResourceManager.start_new_mission()
	var transition_error := await _transition_to_scene(battle_scene_path)
	if transition_error != OK:
		ResourceManager.set_current_expedition_planet(previous_planet_id)
		_update_planet_information()


## Spends ore to pinpoint the selected planet and plays the lock-on reticle.
func locate_selected_planet() -> bool:
	var planet := _star_map_planets[selected_index]
	var profile := ShipEnergySystem.calculate_loadout_profile(ShipLoadout.installed_modules)
	var status := evaluate_launch_requirements(planet, profile, ResourceManager.stored_ore)
	if not bool(status.can_locate):
		_update_planet_information()
		return false
	if not WeaponUnlockManager.locate_planet(StringName(planet["id"]), get_locate_cost(planet)):
		_update_planet_information()
		return false
	var visual := _planet_visuals[selected_index]
	visual.uncharted = false
	visual.lock_on = 1.0
	var tween := visual.create_tween()
	tween.tween_property(visual, "lock_on", 0.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_update_planet_information()
	return true


func _fade_in() -> void:
	transition_overlay.color.a = 1.0
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(transition_overlay, "color:a", 0.0, 0.35)


func _transition_to_scene(scene_path: String) -> Error:
	if _transitioning:
		return ERR_BUSY
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		return ERR_FILE_NOT_FOUND

	_transitioning = true
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(transition_overlay, "color:a", 1.0, 0.24)
	await tween.finished
	var change_error := get_tree().change_scene_to_file(scene_path)
	if change_error != OK:
		_transitioning = false
		transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var restore := create_tween()
		restore.tween_property(transition_overlay, "color:a", 0.0, 0.2)
	return change_error
