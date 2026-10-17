extends Node

## Emitted whenever the current mission's ore amount changes.
signal mission_ore_changed(amount: float)

## Emitted when successfully evacuated ore is added to base storage.
signal stored_ore_changed(amount: float)

## Ore collected during the current mission.
var mission_ore: float = 0.0

## Ore stored permanently at the base.
var stored_ore: float = 0.0

## Prevents a completed mission from being deposited more than once.
var _current_mission_banked: bool = false


## Adds ore collected by mining modules.
func add_mission_ore(amount: float) -> void:
	if amount <= 0.0:
		return

	mission_ore += amount
	mission_ore_changed.emit(mission_ore)
	print("Mission Ore: ", mission_ore)


## Resets resources for a new mission.
func start_new_mission() -> void:
	mission_ore = 0.0
	_current_mission_banked = false
	mission_ore_changed.emit(mission_ore)


## Deposits the current mission's ore once without clearing its HUD value.
func bank_current_mission_ore() -> float:
	if _current_mission_banked:
		return 0.0

	_current_mission_banked = true
	stored_ore += mission_ore
	stored_ore_changed.emit(stored_ore)
	return mission_ore
