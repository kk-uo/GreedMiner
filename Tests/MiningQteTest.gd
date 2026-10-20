extends Node

## Mining QTE system v0.7: Ore Burst rapid clicking, Precision arc check,
## Salvage Chest, global scheduler + one-QTE lock, coexistence with mining /
## combat and cleanup on battle end.

const BATTLE_SCENE: PackedScene = preload("res://Scenes/Battle/BattleMain.tscn")
const MINING_SCENE_PATH: String = "res://Scenes/Modules/Mining/mining_module.tscn"
const MACHINE_GUN_SCENE_PATH: String = "res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn"

var _failures: Array[String] = []
var _executed: Array[String] = []
var battle: Node
var ship: Ship
var manager: MiningQteManager
var mining_a: MiningModule
var mining_b: MiningModule


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	ProgressionStore.set_save_path_for_testing("user://mining_qte_test.json")
	await _setup_battle()
	var reward: float = mining_a.get_effective_ore_per_second() * manager.config.reward_seconds
	_expect_near(reward, 100.0, "salvage reward = effective rate (1 ore / 1 s tick) × 100")

	_test_config_defaults()
	await _test_ore_burst()
	await _test_ore_burst_real_clicks()
	await _test_ore_burst_expiry_and_idle()
	await _test_precision_warning_and_rewards()
	await _test_precision_arc_input()
	await _test_precision_expired_and_rate()
	await _test_salvage_click(reward)
	await _test_salvage_expiry()
	await _test_global_lock()
	await _test_scheduler_frequency()
	await _test_debug_keys()
	await _test_mining_and_combat_continue()
	await _test_reward_once(reward)
	await _test_module_removed_releases_lock()
	await _test_battle_end_cleanup()
	await _test_scene_free_cleanup()
	await _test_evacuation_cleanup()

	ShipLoadout.installed_modules.clear()
	# Keep the isolated path active until this test process exits. Switching back
	# can overwrite the player's real progression during shutdown or reloads.
	await get_tree().process_frame
	print("MINING_QTE_TEST executed: " + ", ".join(_executed))
	if _failures.is_empty():
		print("MINING_QTE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("MINING_QTE_TEST: " + failure)
		print("MINING_QTE_TEST: FAIL (%d failures)" % _failures.size())
		get_tree().quit(1)


func _setup_battle() -> void:
	if is_instance_valid(battle):
		battle.queue_free()
		await get_tree().process_frame
	ResourceManager.start_new_mission()
	ShipLoadout.installed_modules.clear()
	ShipLoadout.install_module(0, 0, MINING_SCENE_PATH)
	ShipLoadout.install_module(0, 2, MINING_SCENE_PATH)
	ShipLoadout.install_module(2, 0, MACHINE_GUN_SCENE_PATH)
	battle = BATTLE_SCENE.instantiate()
	battle.get_node("WaveManager").auto_start = false
	manager = battle.get_node("MiningQteManager") as MiningQteManager
	manager.auto_trigger = false
	manager.config = manager.config.duplicate()
	manager.config.salvage_artifact_chance = 0.0
	add_child(battle)
	await get_tree().process_frame
	ship = battle.get_node("Ship") as Ship
	var minings: Array[MiningModule] = []
	for module in ship.installed_modules.get_children():
		if module is MiningModule:
			minings.append(module)
	mining_a = minings[0] if minings.size() > 0 else null
	mining_b = minings[1] if minings.size() > 1 else null
	_expect_true(mining_a != null and mining_b != null, "two mining modules installed")
	_set_normal_mining(false)


## Normal 1 ore/s mining is paused while QTE payouts are measured (the
## modules stay mining_enabled, so they remain eligible); test 19 restarts it.
func _set_normal_mining(on: bool) -> void:
	for module in [mining_a, mining_b]:
		if is_instance_valid(module):
			var timer := module.get_node("MiningTimer") as Timer
			if on:
				timer.start()
			else:
				timer.stop()


# ------------------------------------------------------------------ 0
func _test_config_defaults() -> void:
	_executed.append("0 config defaults")
	var c := MiningQteManager.DEFAULT_CONFIG
	_expect_near(c.initial_delay, 30.0, "first event at 30 s")
	_expect_near(c.check_interval, 30.0, "an event every 30 s")
	_expect_near(c.chance_per_check, 1.0, "guaranteed every check")
	_expect_true(c.start_when_free, "a check during an event waits for the lock")
	_expect_near(c.weight_ore_burst, 45.0, "ore burst weight 45")
	_expect_near(c.weight_precision, 40.0, "precision weight 40")
	_expect_near(c.weight_salvage, 15.0, "salvage weight 15")
	_expect_near(c.burst_duration, 5.0, "burst 5 s")
	_expect_near(c.burst_click_cooldown, 0.1, "click cooldown 0.1 s")
	_expect_near(c.burst_reward_seconds_per_click, 5.0, "5 s of production per click")
	_expect_near(c.precision_perfect_reward_seconds, 120.0, "perfect 120 s")
	_expect_near(c.precision_success_reward_seconds, 60.0, "success 60 s")
	_expect_near(c.precision_failed_reward_seconds, 10.0, "failed 10 s")
	_expect_true(c.weight_salvage < c.weight_ore_burst and c.weight_salvage < c.weight_precision, "salvage is the rarest event")


# ------------------------------------------------------------------ 1-8
func _test_ore_burst() -> void:
	_executed.append("1 ore burst activates from the marker")
	_executed.append("2 lasts 5 s")
	_executed.append("3 each click = 5 s of production")
	_executed.append("4 clicks under 0.1 s ignored")
	_executed.append("7 counter updates")
	_executed.append("8 total not paid twice")
	var event := manager.try_start_event(MiningQteEvent.TYPE_ORE_BURST, mining_a) as OreBurstEvent
	_expect_true(event != null, "ore burst starts")
	if event == null:
		return
	var per_click: float = mining_a.get_effective_ore_per_second() * 5.0
	_expect_near(event.reward_per_click, per_click, "reward per click = effective rate × 5")
	var before := ResourceManager.mission_ore
	_expect_false(event.register_click(), "clicks before activation do nothing")
	await _click_world(event.global_position + MiningQteEvent.MARKER_OFFSET)
	_expect_true(event.is_bursting(), "clicking the marker starts the burst")
	_expect_near(ResourceManager.mission_ore - before, 0.0, "the activation click pays nothing")
	_expect_true(manager.is_event_active(), "burst phase holds the global lock")
	var start_ms := Time.get_ticks_msec() - int(event._phase_age * 1000.0)
	_expect_true(absf(event.get_time_left() + event._phase_age - 5.0) < 0.001, "burst timer is 5 s")

	_expect_true(event.register_click(), "first click is valid")
	_expect_false(event.register_click(), "a second click in the same instant is ignored (cooldown)")
	_expect_near(ResourceManager.mission_ore - before, per_click, "one valid click paid once")
	_expect_near(event.paid_total, per_click, "counter shows the running total")
	# Step the burst clock by hand so frame hitches can't skew the cooldown.
	event._phase_age += 0.06
	_expect_false(event.register_click(), "click 0.06 s later is still on cooldown")
	event._phase_age += 0.05
	_expect_true(event.register_click(), "click after 0.11 s is valid")
	_expect_near(ResourceManager.mission_ore - before, per_click * 2.0, "two valid clicks = 2 × 5 s of production")
	_expect_true(mining_a.get_impact_amount() > 0.0, "a valid click plays the drill impact")
	_expect_true(event._chips.size() > 0 and event._numbers.size() > 0, "a valid click spawns ore chips and a +X number")

	var resolved: Array = []
	event.resolved.connect(func(_e: MiningQteEvent, outcome: StringName, paid: float) -> void: resolved.append([outcome, paid]))
	while event.is_bursting():
		await get_tree().process_frame
	var lasted: float = (Time.get_ticks_msec() - start_ms) / 1000.0 + 0.11  # + the hand-stepped 0.11 s
	_expect_true(absf(lasted - 5.0) < 0.15, "burst lasts 5 s (%.2f)" % lasted)
	_expect_false(manager.is_event_active(), "lock released when the burst ends")
	_expect_equal(resolved.size(), 1, "resolved exactly once")
	if not resolved.is_empty():
		_expect_equal(resolved[0][0], MiningQteEvent.OUTCOME_SUCCESS, "burst with clicks resolves as success")
		_expect_near(resolved[0][1], per_click * 2.0, "resolve reports the total already paid")
	_expect_near(ResourceManager.mission_ore - before, per_click * 2.0, "completion does not pay the total again")
	_expect_false(event.register_click(), "no clicks count after the burst")
	_expect_equal(event.get_phase(), OreBurstEvent.Phase.SUMMARY, "completion summary shows")
	await _wait(OreBurstEvent.SUMMARY_TIME + 0.2)
	_expect_false(is_instance_valid(event), "summary cleans itself up")


## Real input: press events on the module pay, holding doesn't repeat, clicks
## elsewhere are ignored and never reach the battle's click handling.
func _test_ore_burst_real_clicks() -> void:
	_executed.append("5 holding the mouse does not repeat")
	_executed.append("6 real clicks on the module")
	var event := manager.try_start_event(MiningQteEvent.TYPE_ORE_BURST, mining_a) as OreBurstEvent
	event.activate()
	var before := ResourceManager.mission_ore
	var per_click: float = event.reward_per_click
	var screen := _screen(mining_a.global_position)
	_push_button(screen, true)
	await get_tree().process_frame
	_expect_near(ResourceManager.mission_ore - before, per_click, "a press on the module pays")
	for frame in range(20):
		var motion := InputEventMouseMotion.new()
		motion.position = screen
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(motion, true)
		await get_tree().process_frame
	_expect_near(ResourceManager.mission_ore - before, per_click, "holding the button pays nothing more")
	_push_button(screen, false)
	await _wait(0.12)
	_push_button(screen + Vector2(300.0, 300.0), true)
	_push_button(screen + Vector2(300.0, 300.0), false)
	await get_tree().process_frame
	_expect_near(ResourceManager.mission_ore - before, per_click, "clicks away from the module don't pay")
	_push_button(screen, true)
	_push_button(screen, false)
	await get_tree().process_frame
	_expect_near(ResourceManager.mission_ore - before, per_click * 2.0, "next press after the cooldown pays")
	event.cancel()
	await get_tree().process_frame


func _test_ore_burst_expiry_and_idle() -> void:
	_executed.append("ore burst expiry / idle")
	manager.config.marker_lifetime = 0.2
	var ignored := manager.try_start_event(MiningQteEvent.TYPE_ORE_BURST, mining_a) as OreBurstEvent
	var before := ResourceManager.mission_ore
	await _wait(0.35)
	_expect_equal(ignored.outcome if is_instance_valid(ignored) else MiningQteEvent.OUTCOME_EXPIRED, MiningQteEvent.OUTCOME_EXPIRED, "ignored marker expires")
	_expect_false(manager.is_event_active(), "expired marker releases the lock")
	_expect_near(ResourceManager.mission_ore - before, 0.0, "ignored ore burst pays nothing")
	manager.config.marker_lifetime = 6.0
	manager.config.burst_duration = 0.3
	var idle := manager.try_start_event(MiningQteEvent.TYPE_ORE_BURST, mining_a) as OreBurstEvent
	idle.activate()
	await _wait(0.45)
	_expect_equal(idle.outcome, MiningQteEvent.OUTCOME_FAILED, "a burst with no clicks ends as failed")
	_expect_near(ResourceManager.mission_ore - before, 0.0, "no clicks, no ore")
	manager.config.burst_duration = 5.0
	await _wait(OreBurstEvent.SUMMARY_TIME)


# ------------------------------------------------------------------ 9-14
func _test_precision_warning_and_rewards() -> void:
	_executed.append("9 arc near its module")
	_executed.append("10 2 s preparation")
	_executed.append("11 perfect = 120 s")
	_executed.append("12 success = 60 s")
	_executed.append("13 failure after activation = 10 s")
	var rate: float = mining_a.get_effective_ore_per_second()
	for case in [
		["perfect", MiningQteEvent.OUTCOME_PERFECT, 120.0],
		["success", MiningQteEvent.OUTCOME_SUCCESS, 60.0],
		["miss", MiningQteEvent.OUTCOME_FAILED, 10.0],
		["timeout", MiningQteEvent.OUTCOME_FAILED, 10.0],
	]:
		var event := manager.try_start_event(MiningQteEvent.TYPE_PRECISION, mining_a) as PrecisionMiningEvent
		await _click_world(event.global_position + MiningQteEvent.MARKER_OFFSET)
		var check := event.skill_check
		_expect_true(check != null, "%s: clicking the marker shows the arc" % case[0])
		if check == null:
			continue
		_expect_true(check.get_parent() == event, "%s: arc lives in the battlefield, attached to the event" % case[0])
		await get_tree().process_frame
		var offset: Vector2 = check.global_position - mining_a.global_position
		_expect_true(offset.length() < 140.0 and offset.y < 0.0, "%s: arc sits above its module (%s)" % [case[0], offset])
		_expect_equal(check.phase, MiningSkillCheck.Phase.WARNING, "%s: starts with the warning" % case[0])
		if case[0] == "perfect":
			await _wait(1.8)
			_expect_equal(check.phase, MiningSkillCheck.Phase.WARNING, "still warning at 1.8 s")
			await _wait(0.35)
		else:
			check.advance(manager.config.precision_warning_duration + 0.01)
		_expect_equal(check.phase, MiningSkillCheck.Phase.CHECK, "%s: needle runs after 2 s" % case[0])
		var before := ResourceManager.mission_ore
		var success := manager.config.success_zone_degrees
		var perfect := manager.config.perfect_zone_degrees
		match case[0]:
			"perfect":
				check.needle = check.zone_start + success * 0.5
				check.press()
			"success":
				check.needle = check.zone_start + success * 0.5 + perfect * 0.5 + 3.0
				check.press()
			"miss":
				check.needle = check.zone_start - 8.0
				check.press()
			"timeout":
				check.advance(manager.config.arc_sweep_degrees / manager.config.needle_speed_degrees + 0.05)
		_expect_equal(event.outcome, case[1], "%s: outcome" % case[0])
		_expect_near(ResourceManager.mission_ore - before, rate * float(case[2]), "%s: pays %d s of production" % [case[0], int(case[2])])
		check.press()
		event.resolve(MiningQteEvent.OUTCOME_SUCCESS)
		_expect_near(ResourceManager.mission_ore - before, rate * float(case[2]), "%s: never pays twice" % case[0])
		_expect_false(manager.is_event_active(), "%s: lock released" % case[0])
		await _wait(PrecisionMiningEvent.RESULT_TIME + 0.15)
		_expect_false(is_instance_valid(event), "%s: result feedback cleans up" % case[0])

	# Perfect region is centred inside the success region.
	_expect_equal(MiningSkillCheck.evaluate(130.0, 100.0, 60.0, 12.0), MiningQteEvent.OUTCOME_PERFECT, "centre is perfect")
	_expect_equal(MiningSkillCheck.evaluate(101.0, 100.0, 60.0, 12.0), MiningQteEvent.OUTCOME_SUCCESS, "edge is success")
	_expect_equal(MiningSkillCheck.evaluate(161.0, 100.0, 60.0, 12.0), MiningQteEvent.OUTCOME_FAILED, "past the region fails")
	for index in range(30):
		var start := MiningSkillCheck.random_zone_start(manager.config)
		_expect_true(start >= 0.0 and start + manager.config.success_zone_degrees <= manager.config.arc_sweep_degrees, "random region fits on the arc")


func _test_precision_arc_input() -> void:
	_executed.append("precision space / click on the arc")
	var event := manager.try_start_event(MiningQteEvent.TYPE_PRECISION, mining_a) as PrecisionMiningEvent
	event.activate()
	var check := event.skill_check
	check.advance(manager.config.precision_warning_duration + 0.01)
	check.needle = check.zone_start + manager.config.success_zone_degrees * 0.5
	check.set_process(false)
	_press_space()
	await get_tree().process_frame
	_expect_equal(event.outcome, MiningQteEvent.OUTCOME_PERFECT, "Space stops the needle")
	await _wait(PrecisionMiningEvent.RESULT_TIME + 0.15)

	event = manager.try_start_event(MiningQteEvent.TYPE_PRECISION, mining_a) as PrecisionMiningEvent
	event.activate()
	check = event.skill_check
	check.advance(manager.config.precision_warning_duration + 0.01)
	check.set_process(false)
	check.needle = check.zone_start + manager.config.success_zone_degrees * 0.5
	await get_tree().process_frame
	await _click_world(check.global_position + Vector2(260.0, 220.0))
	_expect_equal(event.outcome, MiningQteEvent.OUTCOME_PERFECT, "clicking empty ground stops the needle too")
	_expect_true(check.result_text.begins_with("PERFECT! +"), "result line shown on the arc (%s)" % check.result_text)
	await _wait(PrecisionMiningEvent.RESULT_TIME + 0.15)


func _test_precision_expired_and_rate() -> void:
	_executed.append("14 ignoring the precision prompt pays nothing")
	manager.config.marker_lifetime = 0.2
	var event := manager.try_start_event(MiningQteEvent.TYPE_PRECISION, mining_a) as PrecisionMiningEvent
	var before := ResourceManager.mission_ore
	await _wait(0.35)
	_expect_false(manager.is_event_active(), "expired precision marker releases the lock")
	_expect_near(ResourceManager.mission_ore - before, 0.0, "ignored precision prompt pays nothing")
	manager.config.marker_lifetime = 6.0
	# Rewards follow the module's effective rate (upgrades / modifiers).
	var old_rate := mining_a.mining_rate
	mining_a.mining_rate = 2.5
	event = manager.try_start_event(MiningQteEvent.TYPE_PRECISION, mining_a) as PrecisionMiningEvent
	event.activate()
	event.skill_check.advance(manager.config.precision_warning_duration + 0.01)
	event.skill_check.needle = event.skill_check.zone_start + manager.config.success_zone_degrees * 0.5
	before = ResourceManager.mission_ore
	event.skill_check.press()
	_expect_near(ResourceManager.mission_ore - before, 2.5 * 120.0, "perfect scales with the module's effective rate")
	mining_a.mining_rate = old_rate
	await _wait(PrecisionMiningEvent.RESULT_TIME + 0.15)


# ------------------------------------------------------------------ 15
func _test_salvage_click(reward: float) -> void:
	_executed.append("15 salvage chest unchanged")
	var chest := manager.try_start_event(MiningQteEvent.TYPE_SALVAGE, mining_a) as SalvageDiscoveryEvent
	_expect_true(chest != null, "salvage starts")
	if chest == null:
		return
	await _wait(SalvageDiscoveryEvent.POP_TIME + 0.1)
	_expect_true(chest.is_waiting(), "chest waits on the ground")
	_expect_true(absf(chest.get_time_left() - manager.config.salvage_lifetime) < 0.3, "chest waits ~30 s")
	var before := ResourceManager.mission_ore
	await _click_world(chest.landing_position)
	_expect_near(ResourceManager.mission_ore - before, reward, "opening the chest pays 100 s of production")
	_expect_false(manager.is_event_active(), "opened chest releases the lock")
	await _wait(SalvageDiscoveryEvent.OPEN_TIME + 0.1)


func _test_salvage_expiry() -> void:
	_executed.append("15 salvage expiry")
	manager.config.salvage_lifetime = 0.2
	var chest := manager.try_start_event(MiningQteEvent.TYPE_SALVAGE, mining_a) as SalvageDiscoveryEvent
	var before := ResourceManager.mission_ore
	await _wait(SalvageDiscoveryEvent.POP_TIME + 0.4)
	_expect_false(manager.is_event_active(), "expired crate releases the lock")
	_expect_near(ResourceManager.mission_ore - before, 0.0, "expired crate pays nothing")
	manager.config.salvage_lifetime = 30.0
	await _wait(0.4)
	_expect_true(chest == null or not is_instance_valid(chest) or chest.is_resolved(), "crate resolved")


# ------------------------------------------------------------------ 8
func _test_global_lock() -> void:
	_executed.append("8 global one-QTE limit")
	var first := manager.try_start_event(MiningQteEvent.TYPE_ORE_BURST, mining_a)
	_expect_true(first != null, "first event starts")
	_expect_true(manager.try_start_event(MiningQteEvent.TYPE_SALVAGE, mining_b) == null, "a second module cannot start another event")
	_expect_true(manager.try_start_event(MiningQteEvent.TYPE_PRECISION, mining_a) == null, "the same module cannot start another event")
	_expect_equal(manager.get_active_event_count(), 1, "exactly one active event")
	first.cancel()
	await get_tree().process_frame

	# Random triggering with every module qualifying every check: never > 1.
	manager.config.initial_delay = 0.0
	manager.config.check_interval = 0.05
	manager.config.cooldown_after_event = 0.0
	manager.config.chance_per_check = 1.0
	manager.config.marker_lifetime = 0.15
	manager.config.salvage_lifetime = 0.15
	manager.auto_trigger = true
	manager.set_next_check_in(0.0)
	var max_seen := 0
	var activations: Array[int] = [0]
	var counter := func(_e: MiningQteEvent) -> void: activations[0] += 1
	manager.event_activated.connect(counter)
	var deadline := Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		max_seen = maxi(max_seen, manager.get_active_event_count())
	manager.event_activated.disconnect(counter)
	manager.auto_trigger = false
	manager.cancel_active_events()
	_expect_true(activations[0] >= 2, "random trigger fires repeatedly (%d)" % activations[0])
	_expect_equal(max_seen, 1, "random triggering never overlaps events")
	manager.config = MiningQteManager.DEFAULT_CONFIG.duplicate()
	await _wait(0.3)


# ------------------------------------------------------------------ 18
## Several Mining Modules never multiply the global frequency: with chance
## 1 per check, the number of events is set by the global checks only.
func _test_scheduler_frequency() -> void:
	_executed.append("17 never simultaneous")
	_executed.append("18 more modules != more events")
	manager.cancel_active_events()
	await get_tree().process_frame
	manager.config = MiningQteManager.DEFAULT_CONFIG.duplicate()
	manager.config.check_interval = 0.2
	manager.config.chance_per_check = 1.0
	manager.config.marker_lifetime = 0.05
	manager.config.weight_ore_burst = 1.0
	manager.config.weight_precision = 0.0
	manager.config.weight_salvage = 0.0
	manager.auto_trigger = true
	manager.set_next_check_in(0.0)
	var activations: Array[int] = [0]
	var counter := func(_e: MiningQteEvent) -> void: activations[0] += 1
	manager.event_activated.connect(counter)
	var max_seen := 0
	var deadline := Time.get_ticks_msec() + 1100
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		max_seen = maxi(max_seen, manager.get_active_event_count())
	manager.event_activated.disconnect(counter)
	manager.auto_trigger = false
	manager.cancel_active_events()
	_expect_equal(max_seen, 1, "never more than one event")
	_expect_true(activations[0] >= 4 and activations[0] <= 7, "one event per global check with 2 modules (%d in 1.1 s at 0.2 s checks)" % activations[0])
	# Checks landing during an active event wait for it: exactly ONE event
	# starts when it ends (not one per missed check).
	manager.config.marker_lifetime = 6.0
	manager.auto_trigger = true
	manager.set_next_check_in(0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var active := manager.get_active_event()
	activations[0] = 0
	manager.event_activated.connect(counter)
	await _wait(0.7)
	_expect_equal(activations[0], 0, "no second event while one is active")
	manager.config.check_interval = 30.0
	if is_instance_valid(active):
		active.cancel()
	await get_tree().process_frame
	await get_tree().process_frame
	manager.event_activated.disconnect(counter)
	_expect_equal(activations[0], 1, "the missed checks start exactly one event once the lock frees")
	manager.auto_trigger = false
	manager.cancel_active_events()
	await get_tree().process_frame
	# Guaranteed cadence: with the real 30 s interval, one event per 30 s.
	manager.config = MiningQteManager.DEFAULT_CONFIG.duplicate()
	manager.config.marker_lifetime = 0.05
	manager.auto_trigger = true
	manager.set_next_check_in(0.0)
	await get_tree().process_frame
	_expect_true(manager.is_event_active() or manager.get_active_event_count() == 0, "check fires")
	var next_in: float = manager._check_timer
	_expect_true(absf(next_in - 30.0) < 0.2, "next guaranteed event is 30 s away (%.2f)" % next_in)
	manager.auto_trigger = false
	manager.cancel_active_events()
	# Weighted pick: salvage is the rarest.
	manager.config = MiningQteManager.DEFAULT_CONFIG.duplicate()
	var counts := {}
	for index in range(3000):
		var type: StringName = manager._pick_type()
		counts[type] = int(counts.get(type, 0)) + 1
	var ore: float = counts.get(MiningQteEvent.TYPE_ORE_BURST, 0) / 3000.0
	var precision: float = counts.get(MiningQteEvent.TYPE_PRECISION, 0) / 3000.0
	var salvage: float = counts.get(MiningQteEvent.TYPE_SALVAGE, 0) / 3000.0
	_expect_true(absf(ore - 0.45) < 0.04 and absf(precision - 0.40) < 0.04 and absf(salvage - 0.15) < 0.03, "weights 45/40/15 (%.2f/%.2f/%.2f)" % [ore, precision, salvage])
	await _wait(0.2)


## Developer builds: F6 / F7 / F8 start each event; the lock still applies.
func _test_debug_keys() -> void:
	_executed.append("debug triggers F6/F7/F8")
	manager.cancel_active_events()
	await get_tree().process_frame
	for entry in [[KEY_F6, MiningQteEvent.TYPE_ORE_BURST], [KEY_F7, MiningQteEvent.TYPE_PRECISION], [KEY_F8, MiningQteEvent.TYPE_SALVAGE]]:
		_press_key(entry[0])
		await get_tree().process_frame
		var active := manager.get_active_event()
		_expect_true(active != null and active.event_type == entry[1], "debug key starts %s" % entry[1])
		_press_key(KEY_F6)
		await get_tree().process_frame
		_expect_equal(manager.get_active_event_count(), 1, "debug keys respect the single-event rule")
		manager.cancel_active_events()
		await get_tree().process_frame
	DeveloperCommands.set_availability_override_for_testing(0)
	_press_key(KEY_F6)
	await get_tree().process_frame
	_expect_false(manager.is_event_active(), "debug keys do nothing outside developer builds")
	DeveloperCommands.set_availability_override_for_testing(-1)


func _press_key(keycode: Key) -> void:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.physical_keycode = keycode
	key.pressed = true
	get_viewport().push_input(key)
	var up := key.duplicate() as InputEventKey
	up.pressed = false
	get_viewport().push_input(up)


# ------------------------------------------------------------------ 19
func _test_mining_and_combat_continue() -> void:
	_executed.append("19 mining continues")
	_executed.append("19 combat not paused")
	_set_normal_mining(true)
	var event := manager.try_start_event(MiningQteEvent.TYPE_PRECISION, mining_a) as PrecisionMiningEvent
	event.activate()
	var before := ResourceManager.mission_ore
	await _wait(1.25)
	_expect_true(mining_a.mining_enabled and not (mining_a.get_node("MiningTimer") as Timer).is_stopped(), "mining timer keeps running during a QTE")
	_expect_true(ResourceManager.mission_ore - before >= 1.0, "normal mining still adds ore during a QTE")
	_expect_false(get_tree().paused, "the tree is not paused during a QTE")
	_expect_near(Engine.time_scale, 1.0, "time scale untouched during a QTE")
	_expect_true(ship.are_weapon_attacks_enabled(), "weapons stay enabled during a QTE")
	_set_normal_mining(false)
	event.cancel()
	await get_tree().process_frame


# ------------------------------------------------------------------ 11
func _test_reward_once(reward: float) -> void:
	_executed.append("20 no duplicate payouts")
	manager.config.salvage_artifact_chance = 0.0
	var event := manager.try_start_event(MiningQteEvent.TYPE_ORE_BURST, mining_a) as OreBurstEvent
	var before := ResourceManager.mission_ore
	event.activate()
	event.activate()
	event.register_click()
	event.resolve(MiningQteEvent.OUTCOME_SUCCESS)
	event.resolve(MiningQteEvent.OUTCOME_PERFECT)
	_expect_near(ResourceManager.mission_ore - before, event.reward_per_click, "repeated activation / resolve pays only the click")
	event.cancel()
	await get_tree().process_frame

	var chest := manager.try_start_event(MiningQteEvent.TYPE_SALVAGE, mining_a) as SalvageDiscoveryEvent
	await _wait(SalvageDiscoveryEvent.POP_TIME + 0.1)
	before = ResourceManager.mission_ore
	chest.open()
	chest.open()
	_expect_near(ResourceManager.mission_ore - before, reward, "double-clicking the crate grants once")
	await _wait(0.2)


# ------------------------------------------------------------------ 12a
func _test_module_removed_releases_lock() -> void:
	_executed.append("12 module removed")
	var event := manager.try_start_event(MiningQteEvent.TYPE_SALVAGE, mining_b)
	_expect_true(manager.is_event_active(), "event active before removal")
	ship.remove_module(0, 2)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect_false(manager.is_event_active(), "removing the triggering module releases the lock")
	_expect_true(not is_instance_valid(event) or event.outcome == MiningQteEvent.OUTCOME_CANCELLED, "event cancelled with its module")


# ------------------------------------------------------------------ 12b
func _test_battle_end_cleanup() -> void:
	_executed.append("12 battle end")
	var event := manager.try_start_event(MiningQteEvent.TYPE_PRECISION, mining_a) as PrecisionMiningEvent
	event.activate()
	var check := event.skill_check
	var before := ResourceManager.mission_ore
	battle._handle_ship_destroyed()
	await get_tree().process_frame
	_expect_false(manager.is_event_active(), "ship destroyed cancels the active QTE")
	_expect_false(is_instance_valid(check) and not check.is_queued_for_deletion(), "skill check UI removed")
	_expect_true(manager.try_start_event(MiningQteEvent.TYPE_ORE_BURST, mining_a) == null, "no new QTE after the battle ended")
	_expect_near(ResourceManager.mission_ore - before, 0.0, "no reward from a cancelled QTE")

	await _setup_battle()
	manager.try_start_event(MiningQteEvent.TYPE_SALVAGE, mining_a)
	battle._on_planet_completed(null)
	await get_tree().process_frame
	_expect_false(manager.is_event_active(), "planet completed cancels the active QTE")


# ------------------------------------------------------------------ 12c
func _test_scene_free_cleanup() -> void:
	_executed.append("12 scene transition")
	await _setup_battle()
	var event := manager.try_start_event(MiningQteEvent.TYPE_SALVAGE, mining_a)
	var before := ResourceManager.mission_ore
	battle.queue_free()
	await get_tree().process_frame
	_expect_false(is_instance_valid(event), "freeing the battle frees the QTE")
	_expect_near(ResourceManager.mission_ore - before, 0.0, "no reward granted on scene exit")


# ------------------------------------------------------------------ 12d
func _test_evacuation_cleanup() -> void:
	_executed.append("12 evacuation")
	await _setup_battle()
	manager.try_start_event(MiningQteEvent.TYPE_ORE_BURST, mining_a)
	# BattleMain changes scene after the takeoff; keep this test node alive by
	# making a throwaway node the "current scene" that gets replaced.
	var stand_in := Node.new()
	get_tree().root.add_child(stand_in)
	get_tree().current_scene = stand_in
	battle._on_evacuation_completed()
	_expect_false(manager.is_event_active(), "evacuation cancels the active QTE immediately")
	_expect_true(manager.try_start_event(MiningQteEvent.TYPE_ORE_BURST, mining_a) == null, "no new QTE while evacuating")
	battle.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------ helpers
func _click_world(world_point: Vector2) -> void:
	var viewport := get_viewport()
	# World → viewport pixels through the battle's camera (same transform the
	# QTE nodes use for make_input_local).
	var screen: Vector2 = manager.get_global_transform_with_canvas() * manager.to_local(world_point)
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	viewport.push_input(motion, true)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen
	press.global_position = screen
	viewport.push_input(press, true)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	viewport.push_input(release, true)
	await get_tree().process_frame


func _screen(world_point: Vector2) -> Vector2:
	return manager.get_global_transform_with_canvas() * manager.to_local(world_point)


func _push_button(screen: Vector2, pressed: bool) -> void:
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = pressed
	button.position = screen
	button.global_position = screen
	get_viewport().push_input(button, true)


func _press_space() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	get_viewport().push_input(key)
	var up := key.duplicate() as InputEventKey
	up.pressed = false
	get_viewport().push_input(up)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _expect_true(value: bool, description: String) -> void:
	if not value:
		_failures.append(description)


func _expect_false(value: bool, description: String) -> void:
	_expect_true(not value, description)


func _expect_equal(actual: Variant, expected: Variant, description: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [description, expected, actual])


func _expect_near(actual: float, expected: float, description: String) -> void:
	if absf(actual - expected) > 0.001:
		_failures.append("%s (expected %.3f, got %.3f)" % [description, expected, actual])
