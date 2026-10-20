extends Node2D

## Isolated runtime checks; this scene is never part of a production wave.
var weather: WeatherManager
var failures: int = 0
var freeze_calls: int = 0

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: " + label)

func freeze_ship_input(duration: float) -> void:
	freeze_calls += 1
	weather.freeze_input(duration)

func make_enemy(id: StringName) -> FrozenEnemy:
	var enemy := EnemyCatalog.instantiate_enemy(id) as FrozenEnemy
	add_child(enemy)
	enemy.set_physics_process(false)
	return enemy

func _ready() -> void:
	weather = WeatherManager.new()
	weather.name = "WeatherManager"
	add_child(weather)
	await get_tree().process_frame
	var snow := make_enemy(&"snow_monster")
	var wizard := make_enemy(&"snow_monster_wizard")
	var wizard2 := make_enemy(&"snow_monster_wizard")
	check(snow.max_health == 50 and snow.move_speed == 30 and snow.reward_ore == 1, "snow stats")
	check(wizard.minimum_spawn_wave == 5 and wizard.attack_type == BasicEnemy.AttackType.RANGED, "wizard metadata")
	wizard._physics_process(4.9)
	check(weather.current_weather == WeatherManager.Weather.NONE, "no premature blizzard")
	wizard._physics_process(0.1)
	wizard2._physics_process(5.0)
	check(weather.current_weather == WeatherManager.Weather.BLIZZARD_NORMAL and snow.move_speed == 40, "wizard bonus does not stack")
	check(wizard.move_speed == 20, "wizard excluded from bonus")
	var boss := make_enemy(&"mega_monster")
	var ship := preload("res://Scenes/Ship/ship.tscn").instantiate() as Ship
	add_child(ship)
	boss.target_ship = ship
	check(boss.max_health == 7000 and boss._entrance_left == 5.0 and weather.current_weather == WeatherManager.Weather.BLIZZARD_BOSS, "boss entrance and weather priority")
	boss._physics_process(5.0)
	boss._on_boss_health_changed(3500, 7000)
	boss._physics_process(4.9)
	check(freeze_calls == 0, "snowball windup")
	boss._physics_process(0.2)
	var special_projectile: HostileProjectile
	for child in get_children():
		if child is HostileProjectile:
			special_projectile = child
	check(special_projectile != null and freeze_calls == 0, "snowball must hit before freezing")
	if special_projectile != null:
		special_projectile._on_ship_hit()
	check(freeze_calls == 1 and weather.is_input_frozen(), "snowball freeze")
	weather._process(5.0)
	check(weather.is_input_frozen() and is_equal_approx(weather.get_freeze_remaining(), 5.0), "freeze lasts 10 s")
	for click in range(4):
		weather.qte_click()
	check(is_equal_approx(weather.get_freeze_remaining(), 3.0), "each QTE click removes 0.5 s")
	weather._process(2.9)
	check(weather.is_input_frozen(), "freeze lasts until deadline")
	weather._process(0.2)
	check(not weather.is_input_frozen(), "freeze ends")
	boss._on_boss_health_changed(100, 7000)
	boss._physics_process(6.0)
	check(freeze_calls == 1, "snowball triggers once")
	boss._die()
	check(weather.current_weather == WeatherManager.Weather.BLIZZARD_NORMAL, "boss death restores normal weather")
	wizard._die()
	wizard2._die()
	check(weather.current_weather == WeatherManager.Weather.BLIZZARD_NORMAL, "wizard death lingers")
	await get_tree().create_timer(2.1).timeout
	check(weather.current_weather == WeatherManager.Weather.NONE and snow.move_speed == 30, "wizard weather ends after delay")
	snow.queue_free()
	await get_tree().process_frame
	var crying_boss := make_enemy(&"mega_monster")
	crying_boss._entrance_left = 0.0
	crying_boss.begin_final_enrage()
	crying_boss._physics_process(2.9)
	check(not crying_boss._enraged, "mega monster cries first")
	crying_boss._physics_process(0.2)
	check(crying_boss._enraged and is_equal_approx(crying_boss.damage_reduction, 0.4) and crying_boss.move_speed == 10, "mega monster enrage (no speed bonus)")
	crying_boss.queue_free()
	var sled := make_enemy(&"sled_car_snow_monster")
	check(sled.max_health == 250 and sled.move_speed == 75 and is_equal_approx(sled.damage_reduction, 0.2), "sled stats")
	sled.target_ship = ship
	ship._all_modules_active = false
	ship.current_hp = ship.max_hp
	var health_before := ship.current_hp
	sled._start_attacking()
	check(not sled.is_dying() and sled._is_attacking and is_equal_approx(ship.current_hp, health_before - sled.attack_damage), "sled immediately attacks and survives contact")
	sled._start_attacking()
	check(is_equal_approx(ship.current_hp, health_before - sled.attack_damage), "continuous contact does not repeat immediate attack")
	var health_before_death := ship.current_hp
	sled._die()
	check(is_equal_approx(ship.current_hp, health_before_death), "sled death burst deals no damage")
	await get_tree().process_frame
	await get_tree().process_frame
	var snow_children: Array[Node] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is FrozenEnemy and node.enemy_id == &"snow_monster":
			snow_children.append(node)
	check(snow_children.size() == 4, "sled spawns four snow monsters")
	if snow_children.size() == 4:
		check(snow_children[0].global_position.distance_to(snow_children[1].global_position) >= 24.0, "split positions do not overlap")
	print("Frozen tests: %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)
