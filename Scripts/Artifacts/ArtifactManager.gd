extends Node

## Owns permanent artifact collection, equipment, tutorial progression and
## runtime effect creation. UI may call this API but never owns artifact state.

signal artifact_granted(definition: MagicArtifactDefinition, first_artifact: bool)
signal collection_changed(artifact_id: StringName, owned: bool)
signal equipment_changed(artifact_id: StringName, location: String)
signal stall_unlocked_changed(unlocked: bool)
signal tutorial_state_changed(pending: bool, completed: bool)
signal artifact_operation_failed(reason: String)

const SAVE_SECTION: StringName = &"magic_artifacts"
const SAVE_VERSION: int = 1
const SHIP_SLOT_COUNT: int = 3
const DEFAULT_CONFIGURATION: MagicArtifactConfiguration = preload(
	"res://Resources/Artifacts/ArtifactConfiguration.tres"
)

var configuration: MagicArtifactConfiguration = DEFAULT_CONFIGURATION
var owned_artifact_ids: Dictionary = {}
var ship_slots: Array[StringName] = [&"", &"", &""]
## One instance-local slot per installed module cell. Key format: "row,column".
var module_slots: Dictionary = {}
var stall_unlocked: bool = false
var tutorial_pending: bool = false
var tutorial_completed: bool = false
var first_artifact_id: StringName = &""
## Owned artifact ids in the order they were acquired (oldest first).
var acquired_order: Array[StringName] = []
var equipment_changes_enabled: bool = true
## Transient actual damage and healing per weapon instance; never saved.
var _weapon_battle_activity: Dictionary = {}
var _battle_activity_ship: Ship


func _ready() -> void:
	for message in configuration.get_validation_errors():
		push_error("ArtifactManager: " + message)
	reload_progress()
	ShipLoadout.cell_changed.connect(_on_ship_cell_changed)
	ShipLoadout.cells_swapped.connect(_on_ship_cells_swapped)


func reload_progress() -> void:
	owned_artifact_ids.clear()
	ship_slots = [&"", &"", &""]
	module_slots.clear()
	stall_unlocked = false
	tutorial_pending = false
	tutorial_completed = false
	first_artifact_id = &""
	acquired_order.clear()

	var data := ProgressionStore.get_section(SAVE_SECTION)
	var raw_owned: Variant = data.get("owned", {})
	if raw_owned is Dictionary:
		for raw_id in (raw_owned as Dictionary).keys():
			var artifact_id := StringName(String(raw_id))
			if bool((raw_owned as Dictionary)[raw_id]) and configuration.get_definition(artifact_id) != null:
				owned_artifact_ids[String(artifact_id)] = true

	stall_unlocked = bool(data.get("stall_unlocked", false)) or not owned_artifact_ids.is_empty()
	tutorial_completed = bool(data.get("tutorial_completed", false))
	tutorial_pending = bool(data.get("tutorial_pending", false)) and not tutorial_completed
	first_artifact_id = StringName(String(data.get("first_artifact_id", "")))
	if first_artifact_id.is_empty() and not owned_artifact_ids.is_empty():
		first_artifact_id = StringName(String(owned_artifact_ids.keys()[0]))

	var raw_order: Variant = data.get("acquired_order", [])
	if raw_order is Array:
		for raw_id in raw_order:
			var ordered_id := StringName(String(raw_id))
			if owns_artifact(ordered_id) and not acquired_order.has(ordered_id):
				acquired_order.append(ordered_id)
	# Older saves have no order: keep the configuration order for them.
	for definition in configuration.definitions:
		if definition != null and owns_artifact(definition.artifact_id) and not acquired_order.has(definition.artifact_id):
			acquired_order.append(definition.artifact_id)

	var used: Dictionary = {}
	var raw_ship_slots: Variant = data.get("ship_slots", [])
	if raw_ship_slots is Array:
		for slot_index in range(mini((raw_ship_slots as Array).size(), SHIP_SLOT_COUNT)):
			var artifact_id := StringName(String((raw_ship_slots as Array)[slot_index]))
			var definition := configuration.get_definition(artifact_id)
			if (
				definition != null
				and owns_artifact(artifact_id)
				and definition.equip_target == MagicArtifactDefinition.EquipTarget.SHIP
				and not used.has(String(artifact_id))
			):
				ship_slots[slot_index] = artifact_id
				used[String(artifact_id)] = true

	var raw_module_slots: Variant = data.get("module_slots", {})
	if raw_module_slots is Dictionary:
		for raw_key in (raw_module_slots as Dictionary).keys():
			var key := String(raw_key)
			var cell := _parse_cell_key(key)
			var artifact_id := StringName(String((raw_module_slots as Dictionary)[raw_key]))
			if _is_valid_module_assignment(cell, artifact_id) and not used.has(String(artifact_id)):
				module_slots[key] = artifact_id
				used[String(artifact_id)] = true

	# Persist the sanitized state so invalid legacy assignments do not return.
	if not data.is_empty():
		save_progress()


func save_progress() -> bool:
	var serialized_ship_slots: Array[String] = []
	for artifact_id in ship_slots:
		serialized_ship_slots.append(String(artifact_id))
	var serialized_module_slots: Dictionary = {}
	for key in module_slots:
		serialized_module_slots[String(key)] = String(module_slots[key])
	return ProgressionStore.set_section(SAVE_SECTION, {
		"version": SAVE_VERSION,
		"owned": owned_artifact_ids.duplicate(true),
		"ship_slots": serialized_ship_slots,
		"module_slots": serialized_module_slots,
		"stall_unlocked": stall_unlocked,
		"tutorial_pending": tutorial_pending,
		"tutorial_completed": tutorial_completed,
		"first_artifact_id": String(first_artifact_id),
		"acquired_order": acquired_order.map(func(id: StringName) -> String: return String(id)),
	})


func get_definition(artifact_id: StringName) -> MagicArtifactDefinition:
	return configuration.get_definition(artifact_id)


func get_all_definitions() -> Array[MagicArtifactDefinition]:
	return configuration.definitions.duplicate()


func owns_artifact(artifact_id: StringName) -> bool:
	return bool(owned_artifact_ids.get(String(artifact_id), false))


func get_owned_artifact_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for definition in configuration.definitions:
		if definition != null and owns_artifact(definition.artifact_id):
			result.append(definition.artifact_id)
	return result


## Discover chest rewards from the registry rather than a hard-coded list.
func get_unowned_mining_chest_artifacts(planet_id: StringName = &"") -> Array[MagicArtifactDefinition]:
	if planet_id.is_empty():
		planet_id = ResourceManager.current_expedition_planet_id
	var result: Array[MagicArtifactDefinition] = []
	for definition in configuration.definitions:
		if definition != null and definition.mining_chest_reward and not owns_artifact(definition.artifact_id) and (definition.mining_chest_planet_ids.is_empty() or definition.mining_chest_planet_ids.has(planet_id)):
			result.append(definition)
	return result


## Called at actual health changes; overkill and overhealing are excluded.
func record_battle_activity(source_weapon: WeaponModule, amount: float) -> void:
	if amount <= 0.0 or not is_instance_valid(source_weapon) or not is_instance_valid(_battle_activity_ship):
		return
	if _battle_activity_ship.assembly_mode or _battle_activity_ship.current_hp <= 0.0 or _battle_activity_ship.get_module_cell(source_weapon).x < 0:
		return
	var weapon_id := source_weapon.get_instance_id()
	_weapon_battle_activity[weapon_id] = float(_weapon_battle_activity.get(weapon_id, 0.0)) + amount


## Returns actual damage/healing for this particular installed weapon.
func get_weapon_battle_activity(source_weapon: WeaponModule) -> float:
	if not is_instance_valid(source_weapon):
		return 0.0
	return float(_weapon_battle_activity.get(source_weapon.get_instance_id(), 0.0))


## Universal acquisition entry point for bosses and future mining chests.
## Returns true only for the first successful grant.
func grant_artifact(artifact_id: StringName) -> bool:
	var definition := get_definition(artifact_id)
	if definition == null:
		return _fail("Unknown artifact: %s" % artifact_id)
	if owns_artifact(artifact_id):
		return false
	var previous_owned := owned_artifact_ids.duplicate(true)
	var previous_stall := stall_unlocked
	var previous_pending := tutorial_pending
	var previous_completed := tutorial_completed
	var previous_first := first_artifact_id
	var is_first := owned_artifact_ids.is_empty()
	owned_artifact_ids[String(artifact_id)] = true
	acquired_order.append(artifact_id)
	stall_unlocked = true
	if is_first:
		first_artifact_id = artifact_id
		tutorial_pending = true
		tutorial_completed = false
	if not save_progress():
		owned_artifact_ids = previous_owned
		acquired_order.erase(artifact_id)
		stall_unlocked = previous_stall
		tutorial_pending = previous_pending
		tutorial_completed = previous_completed
		first_artifact_id = previous_first
		return _fail("Could not save artifact ownership.")
	collection_changed.emit(artifact_id, true)
	if stall_unlocked != previous_stall:
		stall_unlocked_changed.emit(stall_unlocked)
	if is_first:
		tutorial_state_changed.emit(tutorial_pending, tutorial_completed)
	artifact_granted.emit(definition, is_first)
	return true


## 0 for the first artifact ever acquired, 1 for the next... (-1 if not owned).
func get_acquisition_index(artifact_id: StringName) -> int:
	return acquired_order.find(artifact_id)


func is_stall_unlocked() -> bool:
	return stall_unlocked


func set_equipment_changes_enabled(enabled: bool) -> void:
	equipment_changes_enabled = enabled


func get_ship_artifact(slot_index: int) -> StringName:
	return ship_slots[slot_index] if slot_index >= 0 and slot_index < SHIP_SLOT_COUNT else &""


## Legacy equipped slots stay usable until emptied; no saved item is removed.
func is_ship_slot_unlocked(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= SHIP_SLOT_COUNT:
		return false
	if not ship_slots[slot_index].is_empty():
		return true
	var count := 0
	for effect in ResearchManager.get_ship_research_effects():
		count += effect.artifact_slots
	return slot_index < mini(count, SHIP_SLOT_COUNT)


func equip_ship_artifact(slot_index: int, artifact_id: StringName) -> bool:
	if not equipment_changes_enabled:
		return _fail("Magic artifacts can only be changed at the base.")
	if slot_index < 0 or slot_index >= SHIP_SLOT_COUNT:
		return _fail("Invalid ship artifact slot.")
	if not is_ship_slot_unlocked(slot_index):
		return _fail("Research is required to unlock this ship artifact slot.")
	var definition := get_definition(artifact_id)
	if definition == null or not owns_artifact(artifact_id):
		return _fail("Artifact is not owned.")
	if definition.equip_target != MagicArtifactDefinition.EquipTarget.SHIP:
		return _fail("This artifact cannot be equipped to the ship.")
	if ship_slots[slot_index] == artifact_id:
		return true
	var previous_ship := ship_slots.duplicate()
	var previous_modules := module_slots.duplicate(true)
	_remove_artifact_from_all_slots(artifact_id)
	ship_slots[slot_index] = artifact_id
	if not save_progress():
		ship_slots = previous_ship
		module_slots = previous_modules
		return _fail("Could not save artifact equipment.")
	equipment_changed.emit(artifact_id, "ship.%d" % slot_index)
	return true


func unequip_ship_artifact(slot_index: int) -> bool:
	if not equipment_changes_enabled:
		return _fail("Magic artifacts can only be changed at the base.")
	if slot_index < 0 or slot_index >= SHIP_SLOT_COUNT or ship_slots[slot_index].is_empty():
		return false
	var artifact_id := ship_slots[slot_index]
	ship_slots[slot_index] = &""
	if not save_progress():
		ship_slots[slot_index] = artifact_id
		return _fail("Could not save artifact equipment.")
	equipment_changed.emit(artifact_id, "")
	return true


func get_module_artifact(cell: Vector2i) -> StringName:
	return StringName(String(module_slots.get(_cell_key(cell), "")))


func equip_module_artifact(cell: Vector2i, artifact_id: StringName) -> bool:
	if not equipment_changes_enabled:
		return _fail("Magic artifacts can only be changed at the base.")
	if not _is_valid_module_assignment(cell, artifact_id):
		return _fail("Artifact is missing or incompatible with this module instance.")
	var previous_ship := ship_slots.duplicate()
	var previous_modules := module_slots.duplicate(true)
	_remove_artifact_from_all_slots(artifact_id)
	module_slots[_cell_key(cell)] = artifact_id
	if not save_progress():
		ship_slots = previous_ship
		module_slots = previous_modules
		return _fail("Could not save artifact equipment.")
	equipment_changed.emit(artifact_id, "module.%s" % _cell_key(cell))
	return true


func unequip_module_artifact(cell: Vector2i) -> bool:
	if not equipment_changes_enabled:
		return _fail("Magic artifacts can only be changed at the base.")
	var key := _cell_key(cell)
	if not module_slots.has(key):
		return false
	var artifact_id := StringName(String(module_slots[key]))
	module_slots.erase(key)
	if not save_progress():
		module_slots[key] = artifact_id
		return _fail("Could not save artifact equipment.")
	equipment_changed.emit(artifact_id, "")
	return true


func is_artifact_equipped(artifact_id: StringName) -> bool:
	return ship_slots.has(artifact_id) or module_slots.values().has(artifact_id)


func is_ship_artifact_equipped(artifact_id: StringName) -> bool:
	return ship_slots.has(artifact_id)


func get_equipped_location(artifact_id: StringName) -> String:
	var ship_index := ship_slots.find(artifact_id)
	if ship_index >= 0:
		return "Ship Slot %d" % (ship_index + 1)
	for key in module_slots:
		if StringName(String(module_slots[key])) == artifact_id:
			return "Module %s" % String(key)
	return "Not Equipped"


func complete_tutorial() -> bool:
	if tutorial_completed and not tutorial_pending:
		return true
	var previous_pending := tutorial_pending
	var previous_completed := tutorial_completed
	tutorial_pending = false
	tutorial_completed = true
	if not save_progress():
		tutorial_pending = previous_pending
		tutorial_completed = previous_completed
		return _fail("Could not save artifact tutorial progress.")
	tutorial_state_changed.emit(tutorial_pending, tutorial_completed)
	return true


## Creates one independent runtime node per equipped ship artifact.
func attach_battle_effects(target_ship: Ship) -> Node:
	clear_battle_effects(target_ship)
	if not is_instance_valid(target_ship):
		return null
	_weapon_battle_activity.clear()
	_battle_activity_ship = target_ship
	var container := Node.new()
	container.name = "MagicArtifactEffects"
	target_ship.add_child(container)
	for artifact_id in ship_slots:
		if artifact_id.is_empty():
			continue
		var definition := get_definition(artifact_id)
		if definition == null or definition.effect_script == null:
			continue
		var effect := definition.effect_script.new() as MagicArtifactEffect
		if effect == null:
			push_error("ArtifactManager: %s effect must extend MagicArtifactEffect." % artifact_id)
			continue
		effect.name = String(artifact_id).to_pascal_case()
		effect.configure(definition, target_ship)
		container.add_child(effect)
	for cell in module_slots:
		var position := _parse_cell_key(String(cell))
		var module := target_ship.get_module_at(position.x, position.y) as ShipModule
		var definition := get_definition(StringName(String(module_slots[cell])))
		if module == null or definition == null or definition.effect_script == null:
			continue
		var effect := definition.effect_script.new() as MagicArtifactEffect
		if effect == null:
			continue
		effect.configure(definition, target_ship)
		if effect.has_method("configure_module"):
			effect.call("configure_module", module)
		elif module is WeaponModule and effect.has_method("configure_weapon"):
			effect.call("configure_weapon", module)
		container.add_child(effect)
	return container


func clear_battle_effects(target_ship: Ship) -> void:
	if _battle_activity_ship == target_ship:
		_battle_activity_ship = null
		_weapon_battle_activity.clear()
	if not is_instance_valid(target_ship):
		return
	var container := target_ship.get_node_or_null("MagicArtifactEffects")
	if container == null:
		return
	for child in container.get_children():
		if child is MagicArtifactEffect:
			(child as MagicArtifactEffect).cleanup()
	target_ship.remove_child(container)
	container.queue_free()


func _remove_artifact_from_all_slots(artifact_id: StringName) -> void:
	for index in range(ship_slots.size()):
		if ship_slots[index] == artifact_id:
			ship_slots[index] = &""
	for key in module_slots.keys():
		if StringName(String(module_slots[key])) == artifact_id:
			module_slots.erase(key)


func _is_valid_module_assignment(cell: Vector2i, artifact_id: StringName) -> bool:
	if not ShipLoadout.is_valid_cell(cell.x, cell.y) or not ShipLoadout.has_module(cell.x, cell.y):
		return false
	var definition := get_definition(artifact_id)
	if definition == null or not owns_artifact(artifact_id):
		return false
	var entry := ModuleCatalog.find_by_scene(ShipLoadout.get_module(cell.x, cell.y))
	var module_id := StringName(entry.get("id", &"")) if not entry.is_empty() else &""
	return definition.is_compatible_with_module(module_id)


func _on_ship_cell_changed(cell: Vector2i, old_path: String, new_path: String) -> void:
	if old_path == new_path:
		return
	var key := _cell_key(cell)
	if module_slots.has(key):
		var artifact_id := StringName(String(module_slots[key]))
		module_slots.erase(key)
		save_progress()
		equipment_changed.emit(artifact_id, "")


func _on_ship_cells_swapped(cell_a: Vector2i, cell_b: Vector2i) -> void:
	var key_a := _cell_key(cell_a)
	var key_b := _cell_key(cell_b)
	var value_a := StringName(String(module_slots.get(key_a, "")))
	var value_b := StringName(String(module_slots.get(key_b, "")))
	module_slots.erase(key_a)
	module_slots.erase(key_b)
	if not value_a.is_empty():
		module_slots[key_b] = value_a
	if not value_b.is_empty():
		module_slots[key_a] = value_b
	if not value_a.is_empty() or not value_b.is_empty():
		save_progress()
		equipment_changed.emit(&"", "")


func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func _parse_cell_key(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return Vector2i(-1, -1)
	return Vector2i(int(parts[0]), int(parts[1]))


func _fail(reason: String) -> bool:
	artifact_operation_failed.emit(reason)
	push_warning("ArtifactManager: " + reason)
	return false

