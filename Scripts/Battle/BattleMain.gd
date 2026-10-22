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
const GRAVEYARD_WAVE_CONFIG: PlanetWaveConfig = preload("res://Resources/Waves/GraveyardPlanetWaves.tres")
const TREE_WAVE_CONFIG: PlanetWaveConfig = preload("res://Resources/Waves/TreePlanetWaves.tres")
const EXPEDITION_CONFIGS: Dictionary = {
	&"graveyard_planet": {
		"wave_config": GRAVEYARD_WAVE_CONFIG,
		"theme": &"graveyard",
	},
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
	&"tree_planet": {
		"wave_config": TREE_WAVE_CONFIG,
		"theme": &"forest",
	},
}

@onready var ore_label: Label = $BattleUI/UIRoot/OreCounter/HBoxContainer/OreLabel
@onready var health_label: Label = $BattleUI/UIRoot/HealthCounter/HealthRow/HealthLabel
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
const DWARF_MINING_CONTROLLER := preload("res://Scripts/Mining/DwarfMiningController.gd")
var _dwarf_mining: Node2D
const FOREST_STORMS := preload("res://Scripts/Battle/Forest/ForestStormController.gd")
const FOREST_SETTINGS: ForestPlanetSettings = preload("res://Resources/Forest/ForestPlanetSettings.tres")
const FOREST_ROOT := preload("res://Scripts/Battle/Forest/ForestRoot.gd")
const STRANDED_DWARF := preload("res://Scripts/Battle/Forest/StrandedDwarfMarker.gd")
var _forest_storms: ForestStormController
var _forest_boss: ForestBoss
var _forest_root: ForestRoot

func freeze_ship_input(duration: float) -> void:
	if not _battle_ended:
		$WeatherManager.freeze_input(duration)

func _on_ship_freeze_changed(frozen: bool) -> void:
	if is_instance_valid(ship) and (not _battle_ended or not frozen):
		ship.set_combat_frozen(frozen)
	_update_frost_visual(frozen and not _battle_ended)

## Ice coating the frozen ship (presentation only); shatters when it thaws.
const SHIP_FROST_VISUAL := preload("res://Scripts/VFX/ShipFrostVisual.gd")
const DAMAGE_VIGNETTE := preload("res://Scripts/UI/DamageVignette.gd")
## Short slow-motion beat before the result panels (no instant jump).
const BATTLE_END_BEAT := preload("res://Scripts/VFX/BattleEndBeat.gd")
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


func _open_developer_panel() -> void:
	$BattleUI/UIRoot/SettingsMenu.close_menu()
	$BattleUI/UIRoot/DeveloperPanel.open_panel()

func _ready() -> void:
	$BattleUI/UIRoot/SettingsMenu.developer_mode_requested.connect(_open_developer_panel)
	LanguageManager.language_changed.connect(_on_language_changed)
	$WeatherManager.ship_freeze_changed.connect(_on_ship_freeze_changed)
	ArtifactManager.set_equipment_changes_enabled(false)
	_configure_current_expedition()
	if battlefield.planet_theme == &"rocky" or battlefield.planet_theme == &"forest" or battlefield.has_planet_ores():
		_dwarf_mining = DWARF_MINING_CONTROLLER.new()
		_dwarf_mining.battle = self
		_dwarf_mining.ship = ship
		_dwarf_mining.field = battlefield
		add_child(_dwarf_mining)
		_build_mining_tutorial()
	if battlefield.planet_theme == &"forest":
		_forest_storms = FOREST_STORMS.new() as ForestStormController
		_forest_storms.name = "ForestStorms"
		_forest_storms.battle = self
		_forest_storms.field = battlefield
		_forest_storms.ship = ship
		_forest_storms.enemies = $Enemies
		_forest_storms.wave_manager = wave_manager
		_forest_storms.storm_interval = FOREST_SETTINGS.storm_interval
		_forest_storms.warning_duration = FOREST_SETTINGS.storm_warning_duration
		_forest_storms.storm_duration = FOREST_SETTINGS.storm_duration
		_forest_storms.respawn_spread_duration = FOREST_SETTINGS.respawn_spread_duration
		_forest_storms.maximum_respawns_per_frame = FOREST_SETTINGS.maximum_respawns_per_frame
		add_child(_forest_storms)
		move_child(_forest_storms, $BattleUI.get_index())
		$Enemies.child_entered_tree.connect(_on_forest_enemy_entered)
	if battlefield.planet_theme == &"volcanic" and not battlefield.get_lava_emerge_points().is_empty():
		var emergence: Node = LAVA_EMERGENCE.new()
		emergence.name = "LavaEmergence"
		emergence.battle = self
		emergence.field = battlefield
		emergence.waves = wave_manager
		emergence.ship = ship
		emergence.enemies = $Enemies
		add_child(emergence)
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

	# Red screen edge on every hull hit.
	var vignette: CanvasLayer = DAMAGE_VIGNETTE.new()
	vignette.name = "DamageVignette"
	add_child(vignette)
	var battle_ui := get_node_or_null("BattleUI")
	if battle_ui != null:
		move_child(vignette, battle_ui.get_index())
	vignette.call("watch", ship)

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
	apply_planet_view(planet_theme)

## The boss only blocks escape once the player actually attempts takeoff. A
## root may be cut with the same dwarf dispatch gesture used on forest trees.
func _on_forest_enemy_entered(node: Node) -> void:
	var boss := node as ForestBoss
	if boss == null or boss.enemy_id != &"chainsaw_spaceship_treant":
		return
	_forest_boss = boss
	if not boss.died.is_connected(_on_forest_boss_died):
		boss.died.connect(_on_forest_boss_died)

func _summon_forest_escape_root() -> void:
	evacuation_panel.reset_attempt()
	evacuation_panel.set_external_lock(true)
	_forest_root = FOREST_ROOT.new() as ForestRoot
	_forest_root.name = "EscapeRoot"
	battlefield.get_interactables_root().add_child(_forest_root)
	_forest_root.global_position = ship.to_global(Ship.SHIP_SIZE * 0.5) + Vector2(150.0, 0.0)
	if is_instance_valid(battlefield.forest_terrain):
		battlefield.forest_terrain.escape_root = _forest_root
	_forest_root.felled.connect(_on_forest_escape_root_cut)

func _on_forest_escape_root_cut(_tree: ForestTree) -> void:
	evacuation_panel.set_external_lock(false)

func _on_forest_boss_died(_enemy_id: StringName, _position: Vector2) -> void:
	_forest_boss = null
	if is_instance_valid(_forest_root) and not _forest_root.chopped:
		_forest_root.chop()
	evacuation_panel.set_external_lock(false)

func _stop_forest_storms() -> void:
	if is_instance_valid(_forest_storms):
		_forest_storms.stop_storms()

func _show_stranded_dwarves() -> void:
	var ship_center := ship.to_global(Ship.SHIP_SIZE * 0.5)
	for node in get_tree().get_nodes_in_group("mining_dwarves"):
		var dwarf := node as Node2D
		if not is_instance_valid(dwarf) or dwarf.global_position.distance_to(ship_center) <= 130.0:
			continue
		var marker := STRANDED_DWARF.new() as Node2D
		marker.name = "StrandedDwarfVisual"
		add_child(marker)
		marker.global_position = dwarf.global_position


## Presentation: a planet whose map is bigger (Palette "map_extra", e.g. the
## Graveyard Planet +200 px) also shows that much more of it - the camera
## zooms out so the visible width grows by the same amount. Enemies spawn at
## the view edge (EnemySpawner reads the camera zoom), so they appear that
## much farther out too. Returns the zoom applied.
var _planet_view_applied: bool = false

func apply_planet_view(planet_theme: StringName) -> float:
	var extra := float(Palette.planet(planet_theme).get("map_extra", 0.0))
	if _planet_view_applied or extra <= 0.0 or ship == null or ship.world_camera == null:
		return ship.world_camera.zoom.x if ship != null and ship.world_camera != null else 1.0
	_planet_view_applied = true
	var camera := ship.world_camera
	var view_width := get_viewport_rect().size.x / maxf(camera.zoom.x, 0.001)
	camera.zoom *= view_width / (view_width + extra)
	return camera.zoom.x


## Updates the HUD using whole ore units while preserving fractional resources.
func _on_language_changed(_locale: StringName) -> void:
	_on_mission_ore_changed(ResourceManager.mission_ore)
	# Refresh text only: do not invoke the damage or game-over flow.
	health_label.text = "%d / %d" % [ceili(ship.current_hp), ceili(ship.max_hp)]


## Updates the HUD using whole ore units while preserving fractional resources.
func _on_mission_ore_changed(_amount: float) -> void:
	ore_label.text = tr("ORE  %d") % floori(ResourceManager.mission_ore)


## Updates the battle HUD whenever enemies damage the ship.
func _on_ship_health_changed(current_health: float, maximum_health: float) -> void:
	health_label.text = "%d / %d" % [
		ceili(current_health),
		ceili(maximum_health)
	]

	# Ship destruction always takes priority over an unfinished evacuation.
	if current_health <= 0.0 and not _battle_ended:
		_handle_ship_destroyed()


## Ends combat while keeping the Game Over controls responsive.
func _handle_ship_destroyed() -> void:
	_battle_ended = true
	_stop_forest_storms()
	$WeatherManager.clear_transient_effects()
	if is_instance_valid(_evacuation_tip):
		_evacuation_tip.finish()
	ArtifactManager.clear_battle_effects(ship)
	_shutdown_mining_qte()
	wave_manager.stop_wave_system(&"player_defeated")
	evacuation_panel.set_battle_active(false)
	ship.set_all_modules_active(false)
	await BATTLE_END_BEAT.play(self, ship, &"defeat")
	if not is_inside_tree():
		return
	game_over_panel.show()
	return_to_base_button.disabled = false


## Presentation at the base after this battle (dwarves haul ore / repair).
const BASE_HOMECOMING := preload("res://Scripts/Base/BaseHomecoming.gd")


## Returns to the base without banking ore from the failed mission.
func _on_return_to_base_pressed() -> void:
	if ship.current_hp > 0.0:
		return

	return_to_base_button.disabled = true
	# Presentation: the wrecked ship comes home smoking; the crew repairs it.
	BASE_HOMECOMING.pending = {"kind": &"wrecked"}
	ShipLaunchController.landing_pending_at_base = true
	var change_error := get_tree().change_scene_to_file(BASE_SCENE_PATH)
	if change_error != OK:
		return_to_base_button.disabled = false
		push_error("BattleMain: Failed to return to base: %s" % change_error)


## Banks the mission haul once and returns to the assembly base.
func _on_evacuation_completed() -> void:
	if _battle_ended or ship.current_hp <= 0.0:
		evacuation_panel.set_battle_active(false)
		return
	if is_instance_valid(_forest_boss) and not _forest_boss.is_dying() and not is_instance_valid(_forest_root):
		_summon_forest_escape_root()
		return
	if is_instance_valid(_forest_root) and not _forest_root.chopped:
		evacuation_panel.reset_attempt()
		evacuation_panel.set_external_lock(true)
		return

	_battle_ended = true
	_stop_forest_storms()
	if battlefield.planet_theme == &"forest" and is_instance_valid(_forest_boss) and not _forest_boss.is_dying():
		_show_stranded_dwarves()
	$WeatherManager.clear_transient_effects()
	ArtifactManager.clear_battle_effects(ship)
	_shutdown_mining_qte()
	wave_manager.stop_wave_system(&"evacuated")
	evacuation_panel.set_battle_active(false)
	var hauled := ResourceManager.bank_current_mission_ore()
	BASE_HOMECOMING.pending = {"kind": &"haul", "ore": hauled}

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
	_stop_forest_storms()
	$WeatherManager.clear_transient_effects()
	if is_instance_valid(_evacuation_tip):
		_evacuation_tip.finish()
	ArtifactManager.clear_battle_effects(ship)
	_shutdown_mining_qte()
	evacuation_panel.set_battle_active(false)
	ship.set_all_modules_active(false)
	completion_unlock_label.hide()
	if config != null:
		completion_title_label.text = tr("%s CLEARED") % tr(config.display_name.to_upper())
		var unlocked_ids := WeaponUnlockManager.record_planet_completion(config.planet_id)
		if not unlocked_ids.is_empty():
			var names: Array[String] = []
			for weapon_id in unlocked_ids:
				var definition := WeaponUnlockManager.get_definition(weapon_id)
				names.append(tr(definition.display_name) if definition != null else String(weapon_id))
			completion_unlock_label.text = tr("NEW UNLOCK: %s") % ", ".join(names)
			completion_unlock_label.show()
	await BATTLE_END_BEAT.play(self, ship, &"victory")
	if not is_inside_tree():
		return
	completion_panel.show()
	completion_return_button.disabled = false


## Banks the completed mission's resources and returns to assembly.
func _on_completion_return_to_base_pressed() -> void:
	if not _battle_ended or ship.current_hp <= 0.0:
		return
	completion_return_button.disabled = true
	BASE_HOMECOMING.pending = {"kind": &"haul", "ore": ResourceManager.bank_current_mission_ore()}
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
	if _battle_ended or is_ship_input_frozen():
		return
	if is_instance_valid(_dwarf_mining) and _dwarf_mining.handle_input(event):
		get_viewport().set_input_as_handled()
		return
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
	if battlefield.try_click_zombie_grave(world):
		get_viewport().set_input_as_handled()
		return
	if battlefield.try_click_crystal(world):
		get_viewport().set_input_as_handled()
		return
	if battlefield.try_click_vent(world):
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


## First battle with a Mining Module: a guided "send a dwarf" tutorial
## (MiningTutorial; holds the first wave until the first dwarf is sent).
const MINING_TUTORIAL := preload("res://Scripts/UI/MiningTutorial.gd")
## Volcanic Planet: a pack of demons climbs out of the lava rifts every wave.
const LAVA_EMERGENCE := preload("res://Scripts/Waves/LavaEmergence.gd")


func _build_mining_tutorial() -> void:
	if not MINING_TUTORIAL.should_run(_dwarf_mining):
		return
	var tutorial: Control = MINING_TUTORIAL.new()
	tutorial.name = "MiningTutorial"
	tutorial.battle = self
	tutorial.controller = _dwarf_mining
	$BattleUI/UIRoot.add_child(tutorial)


## First Rock Titan defeat: end the battle and play the Rocky Planet finale
## (RockyFinale). Waves stop, the remaining enemies crumble, the HUD hides;
## the finale banks the ore, records the planet as cleared and returns home.
const ROCKY_FINALE := preload("res://Scripts/Battle/RockyFinale.gd")
const STONE_SHATTER := preload("res://Scripts/VFX/StoneShatter.gd")


func play_rocky_finale(titan_position: Vector2) -> void:
	if _battle_ended:
		return
	_battle_ended = true
	_stop_forest_storms()
	$WeatherManager.clear_transient_effects()
	if is_instance_valid(_evacuation_tip):
		_evacuation_tip.finish()
	ArtifactManager.clear_battle_effects(ship)
	_shutdown_mining_qte()
	wave_manager.stop_wave_system(&"rocky_finale")
	evacuation_panel.set_battle_active(false)
	ship.set_all_modules_active(false)
	$BattleUI.visible = false
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as BasicEnemy
		if enemy != null and is_instance_valid(enemy) and not enemy.is_dying():
			enemy.set_death_effects_enabled(false)
			STONE_SHATTER.spawn(enemy.get_parent(), enemy.global_position, 0.8, false)
			enemy.queue_free()
	for node in get_tree().get_nodes_in_group("mining_dwarves"):
		node.queue_free()
	var finale: Node = ROCKY_FINALE.new()
	finale.name = "RockyFinale"
	finale.set("battle", self)
	finale.set("at", titan_position)
	add_child(finale)


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


## Attack range of a weapon in world units (0 if it has none), including
## range bonuses (for example Demon Prism) so the preview ring matches play.
static func get_weapon_range(weapon: Node) -> float:
	for property in [&"attack_range", &"attack_radius"]:
		var value: Variant = weapon.get(property)
		if value is float or value is int:
			if weapon.has_method("get_modified_attack_range"):
				return float(weapon.call("get_modified_attack_range", float(value)))
			return float(value)
	return 0.0


func _shutdown_mining_qte() -> void:
	if _range_indicator != null:
		_range_indicator.hide_ring()
	if mining_qte_manager != null:
		mining_qte_manager.shutdown()


## Acquisition reveal: icon, name, rarity and what it does (presentation,
## Scripts/UI/Artifacts/ArtifactAcquiredCard.gd).
const ARTIFACT_ACQUIRED_CARD := preload("res://Scripts/UI/Artifacts/ArtifactAcquiredCard.gd")


func _on_artifact_granted(definition: MagicArtifactDefinition, first_artifact: bool) -> void:
	if definition == null:
		return
	ARTIFACT_ACQUIRED_CARD.show_for(self, definition, first_artifact)


func _exit_tree() -> void:
	ArtifactManager.clear_battle_effects(ship)
