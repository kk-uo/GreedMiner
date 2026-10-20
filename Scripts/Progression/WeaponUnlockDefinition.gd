class_name WeaponUnlockDefinition
extends Resource

## Data-only definition for one permanently unlockable weapon type.

enum UnlockCondition {
	STARTING,
	PLANET_COMPLETION,
	UNDECIDED,
}

@export var weapon_id: StringName
@export var display_name: String
@export var unlock_condition: UnlockCondition = UnlockCondition.UNDECIDED
@export var required_planet_id: StringName
@export_multiline var requirement_text: String


func is_starting_unlocked() -> bool:
	return unlock_condition == UnlockCondition.STARTING


func is_unlocked_by_planet(planet_id: StringName) -> bool:
	return (
		unlock_condition == UnlockCondition.PLANET_COMPLETION
		and not required_planet_id.is_empty()
		and required_planet_id == planet_id
	)
