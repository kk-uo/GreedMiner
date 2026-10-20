extends Node2D

## Controls navigation from the combat scene back to the assembly base.

const BASE_SCENE_PATH: String = "res://Scenes/Base/base_main.tscn"
const ROCKY_WAVE_CONFIG: PlanetWaveConfig = preload(
	"res://Resources/Waves/RockyPlanetWaves.tres"
)
const VERDANT_WAVE_CONFIG: PlanetWaveConfig = preload(
	"res://Resources/Waves/VerdantPlanetWaves.tres"
)
const VOLCANIC_WAVE_CONFIG: PlanetWaveConfig = preload(
	"res://Resources/Waves/VolcanicPlanetWaves.tres"
)
const FROZEN_WAVE_CONFIG: PlanetWaveConfig = preload("res://Resources/Waves/FrozenPlanetWaves.tres")
const EXPEDITION_CONFIGS: Dictionary = {
	&"rocky_planet": {
		"wave_config": ROCKY_WAVE_CONFIG,
		"theme": &"rocky",
	},
	&"goblin_planet": {
		"wave_config": VERDANT_WAVE_CONFIG,
		"theme": &"jungle",
	},
	&"volcanic_planet": {
		"wave_config": VOLCANIC_WAVE_CONFIG,
		"theme": &"volcanic",
	},
	&"frozen_planet": {
		"wave_config": FROZEN_WAVE_CONFIG,
		"theme": &"frozen",
	},
}

@onready var ore_label: Label = $BattleUI/UIRoot/OreCounter/HBoxContainer/OreLabel
@onready var health_label: Label = $BattleUI/UIRoot/HealthCounter/HealthLabel
@onready var evacuation_panel: EvacuationPanel = $BattleUI/UIRoot/EvacuationPanel
@onready var game_over_panel: PanelContainer = $BattleUI/UIRoot/GameOverPanel
@onready var return_to_base_button: Button = $BattleUI/UIRoot/GameOverPanel/VBoxContainer/ReturnToBaseButton
@onready var completion_panel: PanelContainer = $BattleUI/UIRoot/CompletionPanel
@onready var completion_title_label: Label = $BattleUI/UIRoot/CompletionPanel/VBoxContainer/TitleLabel
@onready var completion_unlock_label: Label = $BattleUI/UIRoot/CompletionPanel/VBoxContainer/UnlockLabel
@onready var completion_return_button: Button = $BattleUI/UIRoot/CompletionPanel/VBoxContainer/ReturnToBaseButton
@onready var wave_hud: WaveHUD = $BattleUI/UIRoot/WaveStatus/VBoxContainer
@onready var wave_manager: WaveManager = $WaveManager
@onready var ship: Ship = $Ship
@onready var battlefield: Battlefield = $Battlefield
## Optional mining QTE coordinator (one QTE at a time, cleaned up on battle end).
@onready var mining_qte_manager: MiningQteManager = get_node_or_null("MiningQteManager") as MiningQteManager

var _battle_ended: bool = false

func freeze_ship_input(duration: float) -> void:
	if not _battle_ended:
		$WeatherManager.freeze_input(duration)

func _on_ship_freeze_changed(frozen: bool) -> void:
	if is_instance_valid(ship) and (not _battle_ended or not frozen):
		ship.set_combat_frozen(frozen)
	_update_frost_visual(frozen and not _battle_ended)

## Ice coating the frozen ship (presentation only); shatters when it thaws.
const SHIP_FROST_VISUAL := preload("res://Scripts/VFX/ShipFrostVisual.gd")
var _frost_visual: Node2D

func _update_frost_visual(frozen: bool) -> void:
	if frozen:
		if is_instance_valid(_frost_visual) or not is_instance_valid(ship):
			return
		_frost_visual = SHIP_FROST_VISUAL.new()
		_frost_visual.call("setup", $WeatherManager)
		ship.add_child(_frost_visual)
	elif is_instance_valid(_frost_visual):
		_frost_visual.call("release")
		_frost_visual = null

func is_ship_input_frozen() -> bool:
	return $WeatherManager.is_input_frozen()

const TURRET_RANGE_INDICATOR := preload("res://Scripts/Battle/TurretRangeIndicator.gd")
## First critical hull: bullet time + a tip pointing at the EVACUATE button.
const EVACUATION_TIP := preload("res://Scripts/UI/EvacuationTip.gd")
var _evacuation_tip: Control
## Shows the attack range of the turret the player clicked during battle.
var _range_indicator: Node2D


## Boss QTE routing happens before all _unhandled_input consumers. Only a
## click inside an active boss-reserved region is handled here; every click
## outside remains available to mining QTEs, modules and normal gameplay.
func _input(event: InputEvent) -> void:
	if is_ship_input_frozen():
		return
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if _battle_ended:
		return
	var local_event := make_input_local(button) as InputEventMouseButton
	var world_position := to_global(local_event.position)
	for node in get_tree().get_nodes_in_group("boss_qte_targets"):
		var boss := node as DemonLord
		if boss != null and boss.route_qte_click(world_position):
			get_viewport().set_input_as_handled()
			return


func _ready() -> void:
	$WeatherManager.ship_freeze_changed.connect(_on_ship_freeze_changed)
	ChipManager.set_equipment_changes_enabled(false)
	ArtifactManager.set_equipment_changes_enabled(false)
	_configure_current_expedition()
	battlefield.crystal_broken.connect(_on_crystal_broken)
	ArtifactManager.attach_battle_effects(ship)
	_range_indicator = TURRET_RANGE_INDICATOR.new()
	_range_indicator.name = "TurretRangeIndicator"
	add_child(_range_indicator)
	game_over_panel.hide()
	completion_panel.hide()

	if EVACUATION_TIP.should_watch():
		_evacuation_tip = EVACUATION_TIP.new()
		_evacuation_tip.name = "EvacuationTip"
		evacuation_panel.get_parent().add_child(_evacuation_tip)
		# Below the evacuation button so it stays clickable.
		evacuation_panel.get_parent().move_child(_evacuation_tip, evacuation_panel.get_index())
		_evacuation_tip.setup(ship, evacuation_panel)

	var evacuation_callback := Callable(self, "_on_evacuation_completed")
	if not evacuation_panel.evacuation_completed.is_connected(evacuation_callback):
		evacuation_panel.evacuation_completed.connect(evacuation_callback)

	var ore_callback := Callable(self, "_on_mission_ore_changed")
	if not ResourceManager.mission_ore_changed.is_connected(ore_callback):
		ResourceManager.mission_ore_changed.connect(ore_callback)

	# Synchronize the HUD even if the mission was reset before this scene loaded.
	_on_mission_ore_changed(ResourceManager.mission_ore)

	var health_callback := Callable(self, "_on_ship_health_changed")
	if not ship.health_changed.is_connected(health_callback):
		ship.health_changed.connect(health_callback)

	_on_ship_health_changed(ship.current_hp, ship.max_hp)

	var return_callback := Callable(self, "_on_return_to_base_pressed")
	if not return_to_base_button.pressed.is_connected(return_callback):
		return_to_base_button.pressed.connect(return_callback)

	var completion_return_callback := Callable(self, "_on_completion_return_to_base_pressed")
	if not completion_return_button.pressed.is_connected(completion_return_callback):
		completion_return_button.pressed.connect(completion_return_callback)

	var preparation_callback := Callable(wave_hud, "show_preparation")
	if not wave_manager.wave_preparation_started.is_connected(preparation_callback):
		wave_manager.wave_preparation_started.connect(preparation_callback)
	var countdown_callback := Callable(wave_hud, "update_preparation")
	if not wave_manager.preparation_time_changed.is_connected(countdown_callback):
		wave_manager.preparation_time_changed.connect(countdown_callback)
	var wave_started_callback := Callable(wave_hud, "show_wave")
	if not wave_manager.wave_started.is_connected(wave_started_callback):
		wave_manager.wave_started.connect(wave_started_callback)
	var remaining_callback := Callable(wave_hud, "update_remaining")
	if not wave_manager.remaining_enemy_count_changed.is_connected(remaining_callback):
		wave_manager.remaining_enemy_count_changed.connect(remaining_callback)
	var completed_callback := Callable(self, "_on_planet_completed")
	if not wave_manager.planet_completed.is_connected(completed_callback):
		wave_manager.planet_completed.connect(completed_callback)
	var blocked_callback := Callable(wave_hud, "show_configuration_blocked")
	if not wave_manager.wave_configuration_blocked.is_connected(blocked_callback):
		wave_manager.wave_configuration_blocked.connect(blocked_callback)
	var artifact_callback := Callable(self, "_on_artifact_granted")
	if not ArtifactManager.artifact_granted.is_connected(artifact_callback):
		ArtifactManager.artifact_granted.connect(artifact_callback)


## Applies the transient destination selected before launch. WaveManager starts
## deferred, so this runs before its first wave without adding another manager.
func _configure_current_expedition() -> void:
	# Tests and dedicated battle scenes may inject their own configuration before
	# entering the tree. Only replace the stock BattleMain default.
	if wave_manager.wave_config != ROCKY_WAVE_CONFIG:
		return
	var planet_id := ResourceManager.current_expedition_planet_id
	var config: Dictionary = EXPEDITION_CONFIGS.get(
		planet_id,
		EXPEDITION_CONFIGS[&"rocky_planet"]
	)
	wave_manager.wave_config = config["wave_config"] as PlanetWaveConfig
	var planet_theme := StringName(config["theme"])
	if battlefield.planet_theme != planet_theme:
		battlefield.planet_theme = planet_theme
		battlefield.generate(battlefield.get_map_seed())


## Updates the HUD using whole ore units while preserving fractional resources.
func _on_mission_ore_changed(_amount: float) -> void:
	ore_label.text = "ORE  %d" % floori(ResourceManager.mission_ore)


## Updates the battle HUD whenever enemies damage the ship.
func _on_ship_health_changed(current_health: float, maximum_health: float) -> void:
	health_label.text = "HULL  %d / %d" % [
		ceili(current_health),
		ceili(maximum_health)
	]

	# Ship destruction always takes priority over an unfinished evacuation.
	if current_health <= 0.0 and not _battle_ended:
		_handle_ship_destroyed()


## Ends combat while keeping the Game Over controls responsive.
func _handle_ship_destroyed() -> void:
	_battle_ended = true
	$WeatherManager.clear_transient_effects()
	if is_instance_valid(_evacuation_tip):
		_evacuation_tip.finish()
	ArtifactManager.clear_battle_effects(ship)
	_shutdown_mining_qte()
	wave_manager.stop_wave_system(&"player_defeated")
	evacuation_panel.set_battle_active(false)
	ship.set_all_modules_active(false)
	game_over_panel.show()
	return_to_base_button.disabled = false


## Returns to the base without banking ore from the failed mission.
func _on_return_to_base_pressed() -> void:
	if ship.current_hp > 0.0:
		return

	return_to_base_button.disabled = true
	var change_error := get_tree().change_scene_to_file(BASE_SCENE_PATH)
	if change_error != OK:
		return_to_base_button.disabled = false
		push_error("BattleMain: Failed to return to base: %s" % change_error)


## Banks the mission haul once and returns to the assembly base.
func _on_evacuation_completed() -> void:
	if _battle_ended or ship.current_hp <= 0.0:
		evacuation_panel.set_battle_active(false)
		return

	_battle_ended = true
	$WeatherManager.clear_transient_effects()
	ArtifactManager.clear_battle_effects(ship)
	_shutdown_mining_qte()
	wave_manager.stop_wave_system(&"evacuated")
	evacuation_panel.set_battle_active(false)
	ResourceManager.bank_current_mission_ore()

	# Presentation: take off before leaving, and land again at the base.
	var launcher := get_node_or_null("ShipLaunchController") as ShipLaunchController
	if launcher != null:
		ship.set_all_modules_active(false)
		ShipLaunchController.landing_pending_at_base = true
		await launcher.play_takeoff()
	get_tree().change_scene_to_file(BASE_SCENE_PATH)


## Presents a functional victory state after the final wave and descendants.
func _on_planet_completed(config: PlanetWaveConfig) -> void:
	if _battle_ended:
		return
	_battle_ended = true
	$WeatherManager.clear_transient_effects()
	if is_instance_valid(_evacuation_tip):
		_evacuation_tip.finish()
	ArtifactManager.clear_battle_effects(ship)
	_shutdown_mining_qte()
	evacuation_panel.set_battle_active(false)
	ship.set_all_modules_active(false)
	completion_unlock_label.hide()
	if config != null:
		completion_title_label.text = "%s CLEARED" % config.display_name.to_upper()
		var unlocked_ids := WeaponUnlockManager.record_planet_completion(config.planet_id)
		if not unlocked_ids.is_empty():
			var names: Array[String] = []
			for weapon_id in unlocked_ids:
				var definition := WeaponUnlockManager.get_definition(weapon_id)
				names.append(definition.display_name if definition != null else String(weapon_id))
			completion_unlock_label.text = "NEW UNLOCK: %s" % ", ".join(names)
			completion_unlock_label.show()
	completion_panel.show()
	completion_return_button.disabled = false


## Banks the completed mission's resources and returns to assembly.
func _on_completion_return_to_base_pressed() -> void:
	if not _battle_ended or ship.current_hp <= 0.0:
		return
	completion_return_button.disabled = true
	ResourceManager.bank_current_mission_ore()
	var change_error := get_tree().change_scene_to_file(BASE_SCENE_PATH)
	if change_error != OK:
		completion_return_button.disabled = false
		push_error("BattleMain: Failed to return after completion: %s" % change_error)


## Ends every mining QTE for good (battle over, evacuation, defeat).
# ==========================================
# Battle clicks: pop common enemies, show turret range
# ==========================================

## Left click in battle: a click-eligible enemy under the cursor takes one click
## (CLICKS_TO_POP pops it); otherwise a clicked weapon toggles its range ring,
## and clicking anywhere else hides the ring. QTE prompts handle their own
## clicks first and mark them handled.
func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if _battle_ended:
		return
	var world: Vector2 = to_global((make_input_local(button) as InputEventMouseButton).position)
	var enemy := find_clickable_enemy_at(world)
	if enemy != null:
		enemy.register_click()
		get_viewport().set_input_as_handled()
		return
	if battlefield.try_click_crystal(world):
		get_viewport().set_input_as_handled()
		return
	var module := find_weapon_module_at(world)
	if module != null:
		_range_indicator.toggle(module, get_weapon_range(module))
		get_viewport().set_input_as_handled()
		return
	var knockback := find_knockback_module_at(world)
	if knockback != null:
		# Knockback triggers on enemies within trigger range of the hull.
		_range_indicator.toggle_hull(knockback, ship, Ship.SHIP_SIZE, knockback.get_effective_trigger_range())
		get_viewport().set_input_as_handled()
	else:
		_range_indicator.hide_ring()


## Crystal rewards are mission ore; the artifact itself is permanently saved.
func _on_crystal_broken(world_position: Vector2, is_red: bool) -> void:
	if _battle_ended:
		return
	var reward := 100.0 if is_red and ArtifactManager.owns_artifact(&"red_crystal") else 30.0
	ResourceManager.add_mission_ore(reward)
	RewardPopup.spawn(self, world_position, reward)
	if is_red and not ArtifactManager.owns_artifact(&"red_crystal"):
		ArtifactManager.grant_artifact(&"red_crystal")
	var golem := EnemyCatalog.instantiate_enemy(&"rock_golem")
	if golem != null:
		golem.target_ship = ship
		$Enemies.add_child(golem)
		golem.global_position = world_position


## Nearest clickable, alive, grounded enemy under world_point.
func find_clickable_enemy_at(world_point: Vector2) -> BasicEnemy:
	var best: BasicEnemy = null
	var best_distance: float = INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as BasicEnemy
		if enemy == null or not enemy.is_clickable():
			continue
		if enemy.has_method("is_in_flight") and enemy.call("is_in_flight"):
			continue
		var distance: float = enemy.global_position.distance_to(world_point)
		if distance <= enemy.get_click_radius() and distance < best_distance:
			best = enemy
			best_distance = distance
	return best


## Installed weapon whose plate contains world_point (works with ship rotation).
func find_weapon_module_at(world_point: Vector2) -> WeaponModule:
	if ship == null or ship.installed_modules == null:
		return null
	for child in ship.installed_modules.get_children():
		var weapon := child as WeaponModule
		if weapon == null or not weapon.is_inside_tree():
			continue
		var local: Vector2 = weapon.to_local(world_point)
		if absf(local.x) <= 30.0 and absf(local.y) <= 30.0:
			return weapon
	return null


## Installed Knockback module whose plate contains world_point.
func find_knockback_module_at(world_point: Vector2) -> KnockbackModule:
	if ship == null or ship.installed_modules == null:
		return null
	for child in ship.installed_modules.get_children():
		var knockback := child as KnockbackModule
		if knockback == null or not knockback.is_inside_tree():
			continue
		var local: Vector2 = knockback.to_local(world_point)
		if absf(local.x) <= 30.0 and absf(local.y) <= 30.0:
			return knockback
	return null


## Attack range of a weapon in world units (0 if it has none).
static func get_weapon_range(weapon: Node) -> float:
	for property in [&"attack_range", &"attack_radius"]:
		var value: Variant = weapon.get(property)
		if value is float or value is int:
			return float(value)
	return 0.0


func _shutdown_mining_qte() -> void:
	if _range_indicator != null:
		_range_indicator.hide_ring()
	if mining_qte_manager != null:
		mining_qte_manager.shutdown()


## Minimal non-blocking acquisition notice. Claude Code can replace this node
## without changing ArtifactManager or boss reward logic.
func _on_artifact_granted(definition: MagicArtifactDefinition, first_artifact: bool) -> void:
	if definition == null or not is_instance_valid($BattleUI/UIRoot):
		return
	var toast := PanelContainer.new()
	toast.name = "ArtifactAcquiredToast"
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.offset_left = -250.0
	toast.offset_top = 22.0
	toast.offset_right = 250.0
	toast.offset_bottom = 82.0
	toast.add_theme_stylebox_override("panel", Palette.make_panel_style(Color(Palette.UI_PANEL, 0.96), 10, 16.0, 10.0))
	var label := Label.new()
	label.text = "ARTIFACT ACQUIRED  ·  %s%s" % [
		definition.display_name.to_upper(),
		"\nThe Magic Stall has awakened at the base." if first_artifact else "",
	]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Palette.UI_TEXT)
	label.add_theme_font_size_override("font_size", 15)
	toast.add_child(label)
	$BattleUI/UIRoot.add_child(toast)
	toast.modulate.a = 0.0
	var tween := toast.create_tween()
	tween.tween_property(toast, "modulate:a", 1.0, 0.15)
	tween.tween_interval(4.0)
	tween.tween_property(toast, "modulate:a", 0.0, 0.25)
	tween.tween_callback(toast.queue_free)


func _exit_tree() -> void:
	ArtifactManager.clear_battle_effects(ship)
