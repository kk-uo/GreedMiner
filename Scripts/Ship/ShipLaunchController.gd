class_name ShipLaunchController
extends Node

## Presentation-only take-off and landing sequences for the ship.
##
## Animates Ship.visual_altitude, Ship.thruster_power and the ship's opacity,
## spawns the ThrusterFX exhaust under the ship, and shakes the camera on
## ignition and touchdown. It never changes health, weapons or loadout.

signal sequence_finished

## Set by BattleMain right before returning to base after an evacuation, so the
## base plays a landing on arrival. Reset once consumed.
static var landing_pending_at_base: bool = false

@export var ship_path: NodePath = NodePath("../Ship")
## Play a landing as soon as the scene starts (BattleMain uses this).
@export var play_landing_on_ready: bool = false
@export var landing_duration: float = 1.3
@export var takeoff_duration: float = 1.1

var ship: Ship
var fx: ThrusterFX
var _busy: bool = false


func _ready() -> void:
	ship = get_node_or_null(ship_path) as Ship
	if ship == null:
		push_warning("ShipLaunchController: ship not found at %s" % ship_path)
		return
	fx = ThrusterFX.new()
	fx.name = "ThrusterFX"
	fx.ship = ship
	_attach_fx.call_deferred()
	if play_landing_on_ready:
		# Start hidden in the air so the first frame never pops.
		ship.visual_altitude = 1.0
		ship.modulate.a = 0.0
		play_landing.call_deferred()


## Puts the exhaust right before the ship in draw order (under the hull).
func _attach_fx() -> void:
	var parent := ship.get_parent()
	parent.add_child(fx)
	parent.move_child(fx, ship.get_index())


func is_busy() -> bool:
	return _busy


## Descends from the sky, flares on touchdown, then shuts the engines off.
func play_landing() -> void:
	if ship == null:
		return
	_busy = true
	ship.visual_altitude = 1.0
	ship.thruster_power = 1.0
	ship.modulate.a = 0.0

	var descend := create_tween()
	descend.set_parallel(true)
	descend.tween_property(ship, "modulate:a", 1.0, 0.3)
	descend.tween_property(ship, "visual_altitude", 0.0, landing_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	descend.tween_property(ship, "thruster_power", 0.75, landing_duration)
	await descend.finished

	# Touchdown: a last flare, a burst of puffs, a short shake, engines off.
	ship.thruster_power = 1.0
	if fx != null and fx.is_inside_tree():
		fx.burst(6)
	_shake(5.0, 0.3)
	var cut := create_tween()
	cut.tween_property(ship, "thruster_power", 0.0, 0.6).set_delay(0.1)
	await cut.finished
	_busy = false
	sequence_finished.emit()


## Ignites, shakes, then climbs toward the camera and fades out.
func play_takeoff() -> void:
	if ship == null:
		return
	_busy = true
	var ignite := create_tween()
	ignite.tween_property(ship, "thruster_power", 0.75, 0.35)
	_shake(3.0, 0.45)
	await ignite.finished

	var climb := create_tween()
	climb.set_parallel(true)
	climb.tween_property(ship, "thruster_power", 1.0, 0.2)
	climb.tween_property(ship, "visual_altitude", 1.0, takeoff_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	climb.tween_property(ship, "modulate:a", 0.0, 0.35).set_delay(takeoff_duration - 0.35)
	await climb.finished
	_busy = false
	sequence_finished.emit()


func _shake(strength: float, duration: float) -> void:
	var camera := ship.world_camera
	if camera == null:
		return
	var base_offset := camera.offset
	var shake := create_tween()
	shake.tween_method(func(t: float) -> void:
		var amount := strength * (1.0 - t)
		camera.offset = base_offset + Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
	, 0.0, 1.0, duration)
	shake.tween_callback(func() -> void: camera.offset = base_offset)
