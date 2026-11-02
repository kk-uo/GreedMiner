extends Node

## Headless CPU baseline, not a substitute for browser/GPU playtesting.
## Runs the real forest battle, raising the final-wave trees in 64-enemy
## batches. Set Battlefield.map_seed before entering the tree for repeatability.
const COUNTS := [200, 400, 600, 800, 1000, 1200, 1400, 1600]
const WARMUP_FRAMES := 20
const SAMPLE_FRAMES := 60

func _ready() -> void:
	ResourceManager.set_current_expedition_planet(&"tree_planet")
	var battle := (load("res://Scenes/Battle/BattleMain.tscn") as PackedScene).instantiate() as Node2D
	battle.get_node("WaveManager").auto_start = false
	battle.get_node("Battlefield").map_seed = 20261027
	add_child(battle)
	await get_tree().process_frame
	# Keep this a population/AI test; a saved loadout must not shoot samples.
	battle.get_node("Ship").process_mode = Node.PROCESS_MODE_DISABLED
	var rings := battle.get_node("ForestRings") as ForestRingRaise
	# Stress above the live final-wave cap to locate the hardware limit.
	battle.get_node("Battlefield").forest_terrain.final_canopy_raise_fraction = 1.0
	var available := rings.raise_rings(12)
	rings.set_process(false)
	var enemies := battle.get_node("Enemies") as Node2D
	print("FOREST BENCH available=", available, " seed=20261027")
	for target in COUNTS:
		if target > available:
			break
		while enemies.get_child_count() < target and rings.get_pending_count() > 0:
			rings._process(0.0)
			rings.set_process(false)
		for _i in range(WARMUP_FRAMES):
			await get_tree().process_frame
		var frame: Array[float] = []
		var cpu: Array[float] = []
		var script: Array[float] = []
		var physics: Array[float] = []
		var previous_us := Time.get_ticks_usec()
		for _i in range(SAMPLE_FRAMES):
			await get_tree().process_frame
			var now_us := Time.get_ticks_usec()
			frame.append(float(now_us - previous_us) / 1000.0)
			previous_us = now_us
			var script_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			var physics_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			script.append(script_ms)
			physics.append(physics_ms)
			cpu.append(script_ms + physics_ms)
		frame.sort()
		cpu.sort()
		script.sort()
		physics.sort()
		print("FOREST BENCH count=", enemies.get_child_count(), " frame_median_ms=", snappedf(frame[30], 0.01), " frame_p95_ms=", snappedf(frame[57], 0.01), " cpu_median_ms=", snappedf(cpu[30], 0.01), " cpu_p95_ms=", snappedf(cpu[57], 0.01), " script_p95_ms=", snappedf(script[57], 0.01), " physics_p95_ms=", snappedf(physics[57], 0.01))
	battle.queue_free()
	get_tree().quit()
