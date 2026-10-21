class_name MiningModule
extends ShipModule

## Amount of ore produced per second.
@export var mining_rate: float = 1.0

## Continuous power required by this mining module instance.
@export var power_consumption: int = 2


func get_module_category() -> StringName:
	return CATEGORY_MINING


func get_power_consumption() -> int:
	return maxi(power_consumption, 0)


## Drill animation state (presentation only, see MiningDrillVisual).
var _cycle_time: float = 0.0
var _fx_boost_time: float = 0.0
## Ore Burst click punch (seconds left of IMPACT_TIME). Drawn only; the node's
## transform is never changed.
var _impact_time: float = 0.0
const IMPACT_TIME: float = 0.11
var _particles: Dictionary = {}
var _fx: Node2D


func _ready() -> void:
	_particles = MiningDrillVisual.make_particles(get_instance_id())
	_cycle_time = randf() * MiningDrillVisual.CYCLE_TIME
	# Smoke and shockwave are drawn on a child above neighbouring modules.
	_fx = Node2D.new()
	_fx.name = "DrillFX"
	_fx.z_index = 2
	_fx.draw.connect(_draw_fx)
	add_child(_fx)


func _process(delta: float) -> void:
	if _impact_time > 0.0:
		_impact_time = maxf(_impact_time - delta, 0.0)
		queue_redraw()
	if not mining_enabled:
		return
	_cycle_time = fposmod(_cycle_time + delta, MiningDrillVisual.CYCLE_TIME)
	_fx_boost_time = maxf(_fx_boost_time - delta, 0.0)
	queue_redraw()
	_fx.queue_redraw()


## Ore per second actually produced by this module (MiningTimer ticks).
## Mining QTE rewards are based on this value.
func get_effective_ore_per_second() -> float:
	var timer := get_node_or_null("MiningTimer") as Timer
	var interval: float = timer.wait_time if timer != null else 1.0
	return maxf(mining_rate, 0.0) / maxf(interval, 0.001) + ResearchManager.get_mining_output_bonus()


## Presentation hook for mining QTEs: jump straight to a boosted breakthrough
## (flash, bigger shockwave, smoke burst). Does not change ore production.
func play_qte_burst() -> void:
	_cycle_time = MiningDrillVisual.BREAK * MiningDrillVisual.CYCLE_TIME - 0.02
	_fx_boost_time = MiningDrillVisual.CYCLE_TIME * 0.4
	queue_redraw()


## Presentation hook for an Ore Burst click: a short drill punch + jolt +
## flash (about 0.1 s). Ore production is untouched.
func play_qte_impact() -> void:
	_impact_time = IMPACT_TIME
	queue_redraw()


func get_impact_amount() -> float:
	return _impact_time / IMPACT_TIME


## Draws the drill module (style A): bone plate, bore hole, spinning auger
## that bites down three times and breaks through; see MiningDrillVisual.
func _draw() -> void:
	MiningDrillVisual.draw_module(self, _cycle_time / MiningDrillVisual.CYCLE_TIME, mining_enabled,
			_particles, Palette.local_shadow_offset(self), get_impact_amount())


func _draw_fx() -> void:
	if not mining_enabled:
		return
	var up := Vector2.UP.rotated(-global_rotation)
	var boost: float = 1.5 if _fx_boost_time > 0.0 else 1.0
	MiningDrillVisual.draw_fx(_fx, _cycle_time / MiningDrillVisual.CYCLE_TIME, _particles, up, boost)


func _on_mining_timer_timeout() -> void:
	if not mining_enabled:
		return

	ResourceManager.add_mission_ore(mining_rate + ResearchManager.get_mining_output_bonus() * $MiningTimer.wait_time)


## Whether this module is currently producing ore.
@export var mining_enabled: bool = true

## Enables or disables ore production.
func set_mining_enabled(enabled: bool) -> void:
	mining_enabled = enabled

	queue_redraw()
	if _fx != null:
		_fx.queue_redraw()
	if mining_enabled:
		$MiningTimer.start()
	else:
		$MiningTimer.stop()
