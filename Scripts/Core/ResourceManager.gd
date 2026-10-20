extends Node

## Emitted whenever the current mission's ore amount changes.
signal mission_ore_changed(amount: float)

## Emitted when successfully evacuated ore is added to base storage.
signal stored_ore_changed(amount: float)

const DEFAULT_EXPEDITION_PLANET_ID: StringName = &"rocky_planet"

## Ore collected during the current mission.
var mission_ore: float = 0.0

## Ore stored permanently at the base.
var stored_ore: float = 0.0

## Transient destination selected for the current mission. It is consumed by
## BattleMain and intentionally not saved.
var current_expedition_planet_id: StringName = DEFAULT_EXPEDITION_PLANET_ID

## Prevents a completed mission from being deposited more than once.
var _current_mission_banked: bool = false


func _ready() -> void:
	reload_persistent_resources()


## Reloads permanent resources while keeping current mission state separate.
func reload_persistent_resources() -> void:
	var saved_resources := ProgressionStore.get_section(&"resources")
	stored_ore = maxf(float(saved_resources.get("stored_ore", 0.0)), 0.0)
	stored_ore_changed.emit(stored_ore)


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


func set_current_expedition_planet(planet_id: StringName) -> void:
	current_expedition_planet_id = (
		planet_id if not planet_id.is_empty() else DEFAULT_EXPEDITION_PLANET_ID
	)


## Deposits the current mission's ore once without clearing its HUD value.
func bank_current_mission_ore() -> float:
	if _current_mission_banked:
		return 0.0

	_current_mission_banked = true
	stored_ore += mission_ore
	stored_ore_changed.emit(stored_ore)
	_persist_resources()
	return mission_ore


## Atomically validates and deducts permanent base ore purchases.
func try_spend_stored_ore(amount: int) -> bool:
	if amount < 0 or stored_ore < float(amount):
		return false
	stored_ore -= float(amount)
	stored_ore_changed.emit(stored_ore)
	_persist_resources()
	return true


## Adds permanent ore, used for rewards and transaction rollback.
func add_stored_ore(amount: float) -> bool:
	if amount <= 0.0:
		return false
	stored_ore += amount
	stored_ore_changed.emit(stored_ore)
	_persist_resources()
	return true


func _persist_resources() -> bool:
	var resources := ProgressionStore.get_section(&"resources")
	resources["stored_ore"] = stored_ore
	# Expedition energy was removed; drop the legacy key from old saves.
	resources.erase("stored_energy")
	return ProgressionStore.set_section(&"resources", resources)
