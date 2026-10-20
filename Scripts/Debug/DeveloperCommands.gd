class_name DeveloperCommands
extends RefCounted

## Guarded developer commands. UI code may request operations through this
## class, but every command independently checks availability before mutating
## progression. The project setting is the central production guard, so a
## release can deliberately expose Developer Mode for playtesting builds.

const ENABLE_SETTING: StringName = &"greedminer/developer_mode/enabled"
const CURRENCY_ORE: StringName = &"ore"
const MAX_SAFE_WHOLE_RESOURCE_BALANCE: int = 9007199254740991

## -1 uses the real build guard. Tests may temporarily force 0 or 1.
static var _availability_override: int = -1


static func is_available() -> bool:
	if _availability_override >= 0:
		return _availability_override == 1
	return bool(ProjectSettings.get_setting(ENABLE_SETTING, true))


## Test-only hook for proving that command methods enforce the central guard.
static func set_availability_override_for_testing(value: int) -> void:
	_availability_override = clampi(value, -1, 1)


## Grants a supported currency after strict integer and overflow validation.
## The string boundary prevents LineEdit conversion from silently saturating.
func grant_resource_from_text(currency_id: StringName, amount_text: String) -> Dictionary:
	if not is_available():
		return _failure("Developer Mode is disabled.")
	if currency_id != CURRENCY_ORE:
		return _failure("Unsupported resource type.")

	var parsed := _parse_non_negative_integer(amount_text)
	if not bool(parsed.get("ok", false)):
		return parsed
	var amount := int(parsed.get("value", 0))
	var current_balance := ResourceManager.stored_ore
	if current_balance < 0.0 or float(amount) > float(MAX_SAFE_WHOLE_RESOURCE_BALANCE) - current_balance:
		return _failure("Amount would exceed the safe resource limit.")
	if amount == 0:
		return _success("Granted 0 Ore.")
	if not ResourceManager.add_stored_ore(float(amount)):
		return _failure("Could not save the resource grant.")
	return _success("Granted %d Ore." % amount)


## Unlocks every weapon known by WeaponUnlockManager without completing or
## otherwise changing planet progression.
func unlock_all_weapons() -> Dictionary:
	if not is_available():
		return _failure("Developer Mode is disabled.")

	var locked_before := 0
	for definition in WeaponUnlockManager.configuration.definitions:
		if definition != null and not WeaponUnlockManager.is_weapon_unlocked(definition.weapon_id):
			locked_before += 1
	if locked_before == 0:
		return _success("All weapons are already unlocked.")

	var newly_unlocked := WeaponUnlockManager.unlock_all_configured_weapons()
	if newly_unlocked.size() != locked_before:
		return _failure("Could not save all weapon unlocks.")
	return _success("Unlocked %d weapons." % newly_unlocked.size())


## Grants every registered magic artifact through ArtifactManager so ownership,
## Magic Stall access, collection signals, and persistence stay authoritative.
## Artifacts are intentionally not auto-equipped.
func unlock_all_artifacts() -> Dictionary:
	if not is_available():
		return _failure("Developer Mode is disabled.")

	var locked_before := 0
	for definition in ArtifactManager.get_all_definitions():
		if definition != null and not ArtifactManager.owns_artifact(definition.artifact_id):
			locked_before += 1
	if locked_before == 0:
		return _success("All magic artifacts are already unlocked.")

	var granted := 0
	for definition in ArtifactManager.get_all_definitions():
		if definition == null or ArtifactManager.owns_artifact(definition.artifact_id):
			continue
		if not ArtifactManager.grant_artifact(definition.artifact_id):
			return _failure("Artifact unlock stopped after %d item(s)." % granted)
		granted += 1
	return _success("Unlocked %d magic artifact(s)." % granted)


## Makes every destination in the planet carousel deployable without marking
## any planet as cleared. Locate costs are waived and only the research entries
## that explicitly gate planet travel are completed; weapon upgrades and other
## progression are intentionally untouched.
func unlock_all_planets() -> Dictionary:
	if not is_available():
		return _failure("Developer Mode is disabled.")

	var newly_located := 0
	var completed_access_research := 0
	for planet in PlanetSelect.PLANETS:
		var planet_id := StringName(planet.get("id", &""))
		if planet_id.is_empty():
			continue

		for research_id in ResearchManager.get_planet_access_researches(planet_id):
			if ResearchManager.is_research_completed(research_id):
				continue
			if not ResearchManager.complete_research_for_development(research_id):
				return _failure("Could not complete access research: %s." % research_id)
			completed_access_research += 1

		var locate_cost := int(planet.get("locate_cost", 0))
		if not WeaponUnlockManager.is_planet_located(planet_id, locate_cost):
			# The manager persists the location and sends the normal signal.
			if not WeaponUnlockManager.locate_planet_for_development(planet_id):
				return _failure("Could not locate planet: %s." % planet_id)
			newly_located += 1

	if newly_located == 0 and completed_access_research == 0:
		return _success("All planets are already available.")
	return _success("Unlocked %d planet location(s) and completed %d access research(es)." % [newly_located, completed_access_research])


## Clears the versioned player save and asks each existing manager to rebuild
## its state from current new-game defaults. No manager owns a duplicate reset.
func reset_all_progress() -> Dictionary:
	if not is_available():
		return _failure("Developer Mode is disabled.")
	if not ProgressionStore.reset_all_progress():
		return _failure("Could not write the new-game save.")

	ResourceManager.start_new_mission()
	ResourceManager.set_current_expedition_planet(ResourceManager.DEFAULT_EXPEDITION_PLANET_ID)
	ResourceManager.reload_persistent_resources()
	WeaponUnlockManager.reload_progress()
	ShipLoadout.load_saved()
	ResearchManager.reload_progress()
	ChipManager.reload_progress()
	ArtifactManager.reload_progress()
	return _success("All progression was reset.")


func _parse_non_negative_integer(text: String) -> Dictionary:
	var cleaned := text.strip_edges()
	if cleaned.is_empty():
		return _failure("Enter a whole number of Ore.")
	var value: int = 0
	for index in cleaned.length():
		var code := cleaned.unicode_at(index)
		if code < 48 or code > 57:
			return _failure("Amount must be a non-negative whole number.")
		var digit := code - 48
		if value > (MAX_SAFE_WHOLE_RESOURCE_BALANCE - digit) / 10:
			return _failure("Amount is too large.")
		value = value * 10 + digit
	return {"ok": true, "value": value}


func _success(message: String) -> Dictionary:
	return {"ok": true, "message": message}


func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}
