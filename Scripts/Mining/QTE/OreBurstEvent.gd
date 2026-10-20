class_name OreBurstEvent
extends MiningQteEvent

## QTE 1 — Ore Burst (rapid clicking, v0.7).
##
## MARKER: a yellow hexagonal "!" sits above the Mining Module for
##   marker_lifetime (6 s). Ignored → expires, no reward.
## BURST: clicking the "!" starts burst_duration (5 s) of rapid clicking on
##   the module itself. The activation click does not count. Every valid
##   click (at least burst_click_cooldown = 0.1 s after the previous valid one;
##   faster clicks are ignored, not queued) immediately pays
##   effective ore/s × burst_reward_seconds_per_click (5 s of production) and
##   plays a drill punch, a gold ore spray, a flash and a big "+X" number.
##   The running total floats above the module; a ring shows the time left.
## SUMMARY: the final "+N" pops — a recap of ore already paid, never a
##   second payout. (Numbers only, no labels.) The global lock is released when BURST ends.
## Only real press events count (holding the button does nothing more).

enum Phase { MARKER, BURST, SUMMARY, FADE }

const SUMMARY_TIME: float = 1.3
## Click target around the module centre (module-local units, follows rotation).
const MODULE_HIT_HALF: float = 30.0
const NUGGETS_PER_CLICK: int = 6
const SPARKS_PER_CLICK: int = 5
const CHIP_LIFE: float = 0.7
const NUMBER_LIFE: float = 0.7
const COUNTER_OFFSET := Vector2(0.0, -104.0)
const GRAVITY: float = 720.0

var reward_per_click: float = 0.0
var valid_clicks: int = 0

var _phase: int = Phase.MARKER
var _age: float = 0.0
var _phase_age: float = 0.0
## Burst clock of the last valid click (-INF = none yet).
var _last_click_time: float = -INF
var _chips: Array[Dictionary] = []
var _numbers: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
## Seconds since the last valid click (white ripple), < 0 = none.
var _pop_age: float = -1.0


func _on_begin() -> void:
	_rng.randomize()
	show_click_label = QteStyleScript.claim_click_hint()
	reward_per_click = MiningQteManager.calculate_reward_for_seconds(module, config.burst_reward_seconds_per_click)


func get_phase() -> int:
	return _phase


func is_bursting() -> bool:
	return _phase == Phase.BURST and not is_resolved()


func get_time_left() -> float:
	return maxf(config.burst_duration - _phase_age, 0.0) if _phase == Phase.BURST else 0.0


func _process(delta: float) -> void:
	_age += delta
	_phase_age += delta
	global_position = get_module_position()
	match _phase:
		Phase.MARKER:
			if _age >= config.marker_lifetime:
				resolve(OUTCOME_EXPIRED)
		Phase.BURST:
			if _phase_age >= config.burst_duration:
				_set_phase(Phase.SUMMARY)
				resolve(OUTCOME_SUCCESS if valid_clicks > 0 else OUTCOME_FAILED)
		Phase.SUMMARY:
			if _phase_age >= SUMMARY_TIME:
				queue_free()
		Phase.FADE:
			if _phase_age >= 0.25:
				queue_free()
	if _pop_age >= 0.0:
		_pop_age += delta
	_update_effects(delta)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if is_resolved():
		return
	match _phase:
		Phase.MARKER:
			if _consume_click(event, global_position + MARKER_OFFSET, (MiningQteVisual.MARKER_RADIUS + 8.0) * MiningQteVisual.MARKER_SCALE):
				activate()
		Phase.BURST:
			if _consume_module_click(event):
				register_click()


## Same as clicking the "!": starts the 5 s clicking phase (pays nothing).
func activate() -> void:
	if _phase != Phase.MARKER or is_resolved():
		return
	_last_click_time = -INF
	_set_phase(Phase.BURST)


## One click on the module during BURST. Returns true if it was valid (paid).
func register_click() -> bool:
	if not is_bursting():
		return false
	if _phase_age - _last_click_time < config.burst_click_cooldown:
		return false
	_last_click_time = _phase_age
	_pop_age = 0.0
	valid_clicks += 1
	_pay(reward_per_click)
	if is_module_valid():
		module.play_qte_impact()
	_spawn_click_effects()
	return true


## Left press on the module plate (any rotation); consumed so it never
## reaches enemy clicks / turret selection below.
func _consume_module_click(event: InputEvent) -> bool:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT or not is_module_valid():
		return false
	var world: Vector2 = to_global((make_input_local(button) as InputEventMouseButton).position)
	var local: Vector2 = module.to_local(world)
	if absf(local.x) > MODULE_HIT_HALF or absf(local.y) > MODULE_HIT_HALF:
		return false
	get_viewport().set_input_as_handled()
	return true


## Ore Burst pays per click; nothing more on resolve.
func _reward_for(_result: StringName) -> float:
	return 0.0


func _on_resolved(result: StringName) -> void:
	match result:
		OUTCOME_SUCCESS, OUTCOME_FAILED:
			pass  # SUMMARY keeps playing, frees itself
		OUTCOME_EXPIRED:
			_set_phase(Phase.FADE)
		_:
			queue_free()


func _set_phase(phase: int) -> void:
	_phase = phase
	_phase_age = 0.0


# ==========================================
# Presentation (visual only — chips never grant ore)
# ==========================================

## Ore spray: gold nuggets fountain up out of the bore hole and fall back
## (screen-down gravity), plus a few bright sparks. Visual only.
func _spawn_click_effects() -> void:
	for index in range(NUGGETS_PER_CLICK):
		_chips.append({
			"pos": Vector2(_rng.randf_range(-4.0, 4.0), -4.0),
			"vel": Vector2(_rng.randf_range(-130.0, 130.0), _rng.randf_range(-380.0, -240.0)),
			"rot": _rng.randf_range(0.0, TAU),
			"spin": _rng.randf_range(-12.0, 12.0),
			"size": _rng.randf_range(1.5, 2.3),
			"age": 0.0,
			"spark": false,
		})
	for index in range(SPARKS_PER_CLICK):
		var angle: float = _rng.randf_range(-PI, 0.0)
		_chips.append({
			"pos": Vector2.ZERO,
			"vel": Vector2.RIGHT.rotated(angle) * _rng.randf_range(160.0, 260.0),
			"rot": angle,
			"spin": 0.0,
			"size": _rng.randf_range(1.6, 2.6),
			"age": 0.0,
			"spark": true,
		})
	_numbers.append({
		"text": "+%s" % _format(reward_per_click),
		"x": _rng.randf_range(-18.0, 18.0),
		"age": 0.0,
	})


func _update_effects(delta: float) -> void:
	for chip in _chips:
		chip["age"] += delta
		if chip["spark"]:
			chip["vel"] = (chip["vel"] as Vector2) * exp(-6.0 * delta)
		else:
			chip["vel"] = (chip["vel"] as Vector2) + Vector2(0.0, GRAVITY * delta)
		chip["pos"] += chip["vel"] * delta
		chip["rot"] += chip["spin"] * delta
	_chips = _chips.filter(func(chip: Dictionary) -> bool: return chip["age"] < CHIP_LIFE)
	for number in _numbers:
		number["age"] += delta
	_numbers = _numbers.filter(func(number: Dictionary) -> bool: return number["age"] < NUMBER_LIFE)


static func _format(amount: float) -> String:
	return str(int(round(amount))) if absf(amount - round(amount)) < 0.05 else "%.1f" % amount


func _draw() -> void:
	match _phase:
		Phase.MARKER:
			var pop: float = MiningQteVisual._back_out(clampf(_age / 0.25, 0.0, 1.0))
			QteStyleScript.draw_target(self, MARKER_OFFSET, TARGET_RADIUS * pop, _age)
			if show_click_label:
				QteStyleScript.draw_click_label(self, MARKER_OFFSET, TARGET_RADIUS, _age)
		Phase.FADE:
			QteStyleScript.draw_target(self, MARKER_OFFSET, TARGET_RADIUS, _age, 1.0 - _phase_age / 0.25, false)
		Phase.BURST:
			# White target over the module: keep clicking it.
			QteStyleScript.draw_target(self, Vector2.ZERO, 34.0, _age)
			if _pop_age >= 0.0:
				QteStyleScript.draw_pop(self, Vector2.ZERO, 34.0, _pop_age / QteStyleScript.POP_TIME)
			if show_click_label:
				QteStyleScript.draw_click_label(self, Vector2.ZERO, 34.0, _age)
			# Running total: just the number, big.
			var punch: float = 1.0
			if not _numbers.is_empty():
				punch = 1.0 + 0.18 * maxf(1.0 - float(_numbers.back()["age"]) / 0.15, 0.0)
			draw_set_transform(COUNTER_OFFSET, 0.0, Vector2.ONE * punch)
			MiningQteVisual.draw_text(self, Vector2.ZERO, "+%s" % _format(paid_total), 30, Palette.GOLD)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		Phase.SUMMARY:
			var alpha: float = clampf((SUMMARY_TIME - _phase_age) / 0.35, 0.0, 1.0)
			var pop: float = 1.0 + 0.35 * maxf(1.0 - _phase_age / 0.2, 0.0)
			draw_set_transform(COUNTER_OFFSET + Vector2(0.0, -8.0 * _phase_age), 0.0, Vector2.ONE * pop)
			MiningQteVisual.draw_text(self, Vector2.ZERO, "+%s" % _format(paid_total), 36, Palette.GOLD_LIGHT, alpha)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for chip in _chips:
		var k: float = float(chip["age"]) / CHIP_LIFE
		if chip["spark"]:
			var tail: Vector2 = (chip["vel"] as Vector2) * 0.035
			draw_line(chip["pos"], chip["pos"] - tail, Color(Palette.GOLD_LIGHT, 1.0 - k), float(chip["size"]))
		else:
			MiningQteVisual.draw_ore_chip(self, chip["pos"], float(chip["size"]) * (1.0 - 0.35 * k), chip["rot"], clampf((1.0 - k) * 1.6, 0.0, 1.0))
	for number in _numbers:
		var k: float = float(number["age"]) / NUMBER_LIFE
		var pos := Vector2(float(number["x"]) * 1.6, -34.0 - 30.0 * (1.0 - pow(1.0 - k, 2.0)))
		MiningQteVisual.draw_text(self, pos, number["text"], 20, Palette.GOLD_LIGHT, 1.0 - k * k)
