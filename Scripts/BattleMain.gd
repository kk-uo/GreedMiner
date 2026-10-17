extends Node2D

## Controls navigation from the combat scene back to the assembly base.

const BASE_SCENE_PATH: String = "res://Scenes/base_main.tscn"

@onready var ore_label: Label = $BattleUI/UIRoot/OreCounter/HBoxContainer/OreLabel
@onready var health_label: Label = $BattleUI/UIRoot/HealthCounter/HealthLabel
@onready var evacuation_panel: EvacuationPanel = $BattleUI/UIRoot/EvacuationPanel
@onready var ship: Ship = $Ship

var _battle_ended: bool = false


func _ready() -> void:
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
		_battle_ended = true
		evacuation_panel.set_battle_active(false)


## Banks the mission haul once and returns to the assembly base.
func _on_evacuation_completed() -> void:
	if _battle_ended or ship.current_hp <= 0.0:
		evacuation_panel.set_battle_active(false)
		return

	_battle_ended = true
	evacuation_panel.set_battle_active(false)
	ResourceManager.bank_current_mission_ore()
	get_tree().change_scene_to_file(BASE_SCENE_PATH)
