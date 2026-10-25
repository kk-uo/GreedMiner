class_name MiningQteEvent
extends Node2D

## Base class for one mining QTE. Lives in world space (child of the
## MiningQteManager, not of the ship) and follows its Mining Module.
##
## Lifecycle: begin() → subclass phases → resolve(outcome) exactly once.
## resolve() grants the outcome's reward at most once (_reward_for), emits
## `resolved` with everything this event paid (paid_total), then the subclass
## may keep playing a short outro before freeing itself. The manager releases
## the global lock on `resolved`, not on free. Events that pay while running
## (Ore Burst clicks) add to paid_total via _pay() and pay nothing on resolve.

signal resolved(event: MiningQteEvent, outcome: StringName, reward: float)

const TYPE_ORE_BURST: StringName = &"ore_burst"
const TYPE_PRECISION: StringName = &"precision_mining"
const TYPE_SALVAGE: StringName = &"salvage_discovery"

const OUTCOME_SUCCESS: StringName = &"success"
const OUTCOME_PERFECT: StringName = &"perfect"
const OUTCOME_FAILED: StringName = &"failed"
const OUTCOME_EXPIRED: StringName = &"expired"
const OUTCOME_CANCELLED: StringName = &"cancelled"

## Marker sits this far above the module (screen space, world pixels).
const MARKER_OFFSET := Vector2(0.0, -46.0)
## Radius of the white QTE target drawn at MARKER_OFFSET (see QteStyle).
const TARGET_RADIUS: float = 22.0
const QteStyleScript := preload("res://Scripts/UI/QteStyle.gd")

var event_type: StringName = &""
var module: MiningModule
var config: MiningQteConfig
var manager: MiningQteManager
## Reward fixed when the event starts (effective rate × reward_seconds).
var reward_amount: float = 0.0
var outcome: StringName = &""
## Ore actually paid by this event so far (all sources).
var paid_total: float = 0.0

## True for the player's very first QTE: shows the "CLICK" label.
var show_click_label: bool = false

var _resolved: bool = false
var _reward_claimed: bool = false


func begin(owner_manager: MiningQteManager, source_module: MiningModule, qte_config: MiningQteConfig) -> void:
	manager = owner_manager
	module = source_module
	config = qte_config
	reward_amount = MiningQteManager.calculate_reward(source_module, qte_config)
	z_as_relative = false
	z_index = 30
	global_position = get_module_position()
	_on_begin()


func is_resolved() -> bool:
	return _resolved


func is_reward_claimed() -> bool:
	return _reward_claimed


func is_module_valid() -> bool:
	return is_instance_valid(module) and module.is_inside_tree()


func get_module_position() -> Vector2:
	return module.global_position if is_module_valid() else global_position


## Ends the event once. Success / perfect grant the reward exactly once.
func resolve(result: StringName) -> void:
	if _resolved:
		return
	_resolved = true
	outcome = result
	var amount: float = _reward_for(result)
	if amount > 0.0:
		_claim_reward(amount)
	resolved.emit(self, result, paid_total)
	_on_resolved(result)


## Immediate cleanup (battle end, evacuation, module removed). No reward.
func cancel() -> void:
	resolve(OUTCOME_CANCELLED)
	queue_free()


## Ore paid when the event resolves with result (default: reward_amount on
## success / perfect, nothing otherwise). Subclasses override.
func _reward_for(result: StringName) -> float:
	if result == OUTCOME_SUCCESS or result == OUTCOME_PERFECT:
		return reward_amount
	return 0.0


## Whether the resolve payout shows the big floating RewardPopup.
func _shows_reward_popup() -> bool:
	return true


## The single resolve payout (guarded so it can never pay twice).
func _claim_reward(amount: float) -> float:
	if _reward_claimed or amount <= 0.0:
		return 0.0
	_reward_claimed = true
	_pay(amount)
	if _shows_reward_popup():
		RewardPopup.spawn(get_parent(), global_position + Vector2(0.0, -10.0), amount)
	return amount


## Adds ore to the mission pool (the same pool normal mining uses).
func _pay(amount: float) -> void:
	if amount <= 0.0:
		return
	ResourceManager.add_mission_ore(amount, &"chest" if self is SalvageDiscoveryEvent else &"qte")
	paid_total += amount


## True when a left click landed within radius of a world point.
## Marks the input handled so the click does not reach gameplay below.
func _consume_click(event: InputEvent, world_point: Vector2, radius: float) -> bool:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return false
	var local_click: Vector2 = (make_input_local(button) as InputEventMouseButton).position
	if local_click.distance_to(to_local(world_point)) > radius:
		return false
	get_viewport().set_input_as_handled()
	return true


# Subclass hooks.
func _on_begin() -> void:
	pass


func _on_resolved(_result: StringName) -> void:
	queue_free()
