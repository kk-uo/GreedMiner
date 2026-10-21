class_name PrecisionMiningEvent
extends MiningQteEvent

## QTE 2 — Precision Mining (v0.7). A yellow "!" (round badge) appears above
## the Mining Module for marker_lifetime s; ignoring it pays nothing. Clicking
## it shows the arc skill check right above the module (MiningSkillCheck):
## 2 s warning, then one needle pass. Rewards (× module ore/s):
## Perfect 120 s, Success 60 s, Failed / no input 10 s — paid once; the arc
## shows "PERFECT! +N" semi-transparent above itself. The battle keeps running.

enum Phase { MARKER, CHECKING, DONE, FADE }

var skill_check: MiningSkillCheck

const RESULT_TIME: float = 1.1

var _phase: int = Phase.MARKER
var _age: float = 0.0
var _phase_age: float = 0.0


func _process(delta: float) -> void:
	_age += delta
	_phase_age += delta
	global_position = get_module_position()
	match _phase:
		Phase.MARKER:
			if _age >= config.marker_lifetime:
				resolve(OUTCOME_EXPIRED)
		Phase.CHECKING:
			# The dial was removed from outside (UI torn down): count as a miss.
			if not is_instance_valid(skill_check):
				resolve(OUTCOME_FAILED)
		Phase.DONE:
			if _phase_age >= RESULT_TIME:
				queue_free()
		Phase.FADE:
			if _phase_age >= 0.25:
				queue_free()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _phase != Phase.MARKER or is_resolved():
		return
	if _consume_click(event, global_position + MARKER_OFFSET, (MiningQteVisual.MARKER_RADIUS + 8.0) * MiningQteVisual.MARKER_SCALE):
		activate()


func _on_begin() -> void:
	show_click_label = QteStyleScript.claim_click_hint()


## Same as clicking the marker: opens the skill check (warning first).
func activate() -> void:
	if _phase != Phase.MARKER or is_resolved():
		return
	_set_phase(Phase.CHECKING)
	skill_check = MiningSkillCheck.new()
	skill_check.setup(config, MiningSkillCheck.random_zone_start(config), module)
	skill_check.show_click_label = show_click_label
	skill_check.finished.connect(_on_check_finished)
	add_child(skill_check)
	skill_check.start_warning(config.precision_warning_duration)


func _on_check_finished(result: StringName) -> void:
	resolve(result)


## Seconds of production paid per outcome (nothing when expired / cancelled).
func reward_seconds_for(result: StringName) -> float:
	match result:
		OUTCOME_PERFECT:
			return config.precision_perfect_reward_seconds
		OUTCOME_SUCCESS:
			return config.precision_success_reward_seconds
		OUTCOME_FAILED:
			return config.precision_failed_reward_seconds
	return 0.0


func _reward_for(result: StringName) -> float:
	return MiningQteManager.calculate_reward_for_seconds(module, reward_seconds_for(result))


## Shows its own compact result line instead of the big popup.
func _shows_reward_popup() -> bool:
	return false


func _on_resolved(result: StringName) -> void:
	match result:
		OUTCOME_SUCCESS, OUTCOME_PERFECT, OUTCOME_FAILED:
			# The arc shows the result line ("PERFECT! +120") above itself.
			if is_instance_valid(skill_check):
				skill_check.result_text = "%s +%s" % [tr(result_label(result)), OreBurstEvent._format(paid_total)]
			if result != OUTCOME_FAILED and is_module_valid():
				module.play_qte_burst()
			_set_phase(Phase.DONE)
		OUTCOME_EXPIRED:
			_set_phase(Phase.FADE)
		_:
			if is_instance_valid(skill_check):
				skill_check.queue_free()
			queue_free()


static func result_label(result: StringName) -> String:
	match result:
		OUTCOME_PERFECT:
			return "PERFECT!"
		OUTCOME_SUCCESS:
			return "SUCCESS!"
	return "FAILED"


func _set_phase(phase: int) -> void:
	_phase = phase
	_phase_age = 0.0


func _exit_tree() -> void:
	if is_instance_valid(skill_check) and not skill_check.is_queued_for_deletion():
		skill_check.queue_free()


func _draw() -> void:
	match _phase:
		Phase.MARKER:
			var pop: float = MiningQteVisual._back_out(clampf(_age / 0.25, 0.0, 1.0))
			QteStyleScript.draw_target(self, MARKER_OFFSET, TARGET_RADIUS * pop, _age)
			if show_click_label:
				QteStyleScript.draw_click_label(self, MARKER_OFFSET, TARGET_RADIUS, _age)
		Phase.FADE:
			QteStyleScript.draw_target(self, MARKER_OFFSET, TARGET_RADIUS, _age, 1.0 - _phase_age / 0.25, false)
		Phase.CHECKING:
			# Marks the module being worked.
			QteStyleScript.draw_target(self, Vector2.ZERO, 30.0, _age, 0.6, false)
