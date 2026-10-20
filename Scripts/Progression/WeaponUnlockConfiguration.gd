class_name WeaponUnlockConfiguration
extends Resource

## Inspector-editable collection of stable weapon unlock definitions.

@export var definitions: Array[WeaponUnlockDefinition] = []


func get_definition(weapon_id: StringName) -> WeaponUnlockDefinition:
	for definition in definitions:
		if definition != null and definition.weapon_id == weapon_id:
			return definition
	return null


func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	var seen: Dictionary = {}
	for definition in definitions:
		if definition == null:
			errors.append("Weapon unlock configuration contains an empty definition.")
			continue
		if definition.weapon_id.is_empty():
			errors.append("Weapon unlock definition has no weapon ID.")
		elif seen.has(String(definition.weapon_id)):
			errors.append("Duplicate weapon unlock ID: %s" % definition.weapon_id)
		else:
			seen[String(definition.weapon_id)] = true
		if (
			definition.unlock_condition == WeaponUnlockDefinition.UnlockCondition.PLANET_COMPLETION
			and definition.required_planet_id.is_empty()
		):
			errors.append("Weapon '%s' has no required planet ID." % definition.weapon_id)
	return errors
