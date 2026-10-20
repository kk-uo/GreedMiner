extends Node

## Isolated launcher for one Verdant wave. It never changes normal battle data.

const BATTLE_SCENE: PackedScene = preload("res://Scenes/Battle/BattleMain.tscn")
const VERDANT_CONFIG: PlanetWaveConfig = preload("res://Resources/Waves/VerdantPlanetWaves.tres")

@export_range(1, 10, 1) var wave_number_to_test: int = 1


func _ready() -> void:
	ResourceManager.start_new_mission()
	var battle := BATTLE_SCENE.instantiate()
	var manager := battle.get_node("WaveManager") as WaveManager
	var battlefield := battle.get_node("Battlefield") as Battlefield
	manager.auto_start = false
	manager.spawn_rng_seed = 20261018
	var test_config := PlanetWaveConfig.new()
	test_config.planet_id = &"verdant_manual_test"
	test_config.display_name = "Verdant Manual Test"
	test_config.special_spawn_rules = VERDANT_CONFIG.special_spawn_rules
	test_config.waves = [VERDANT_CONFIG.waves[wave_number_to_test - 1]]
	# Wave 10 must proceed to Wave 11 (Goblin Giant Chariot) instead of reporting victory.
	if wave_number_to_test == 10:
		test_config.waves.append(VERDANT_CONFIG.waves[10])
	manager.wave_config = test_config
	battlefield.planet_theme = &"jungle"
	add_child(battle)
	manager.start_wave_system.call_deferred()
