class_name MagicArtifactDefinition
extends Resource

## Data-only definition for one globally unique magic artifact.
## Presentation reads this resource; gameplay effects live in effect_script.

enum EquipTarget {
	SHIP,
	MODULE,
}

enum AcquisitionMethod {
	BOSS,
	WORLD,
	MINING_CHEST,
	SHOP,
}

@export var artifact_id: StringName
@export var display_name: String = "Unnamed Artifact"
@export var rarity: String = ""
@export var mining_chest_reward: bool = false
## Non-chest acquisition method. Chest rewards use mining_chest_reward as the
## authoritative source, so existing chest definitions need no migration.
@export var acquisition_method: AcquisitionMethod = AcquisitionMethod.BOSS
## -1 means the shop may display this artifact but cannot sell it yet.
@export var shop_price_ore: int = -1
## Empty means any planet; otherwise only these destinations can drop it.
@export var mining_chest_planet_ids: Array[StringName] = []
## Planet whose Compendium row lists this artifact (empty = any planet).
@export var source_planet_id: StringName
## Short source shown under the artifact (for example a boss name).
@export var source_name: String = ""
## effect_parameters keys shown as icon + number chips (at most three).
@export var stat_keys: Array[StringName] = []
@export_multiline var description: String
@export var icon: Texture2D
@export var equip_target: EquipTarget = EquipTarget.SHIP
@export var compatible_module_ids: Array[StringName] = []
## Opt out when an effect only makes sense on explicitly listed fusion weapons.
@export var inherit_fusion_compatibility: bool = true
@export_multiline var acquisition_source: String
@export var unique: bool = true
@export var effect_script: Script
@export var effect_parameters: Dictionary = {}


func get_acquisition_method() -> AcquisitionMethod:
	return AcquisitionMethod.MINING_CHEST if mining_chest_reward else acquisition_method


func is_compatible_with_module(module_id: StringName) -> bool:
	return (
		equip_target == EquipTarget.MODULE
		and not module_id.is_empty()
		and (compatible_module_ids.is_empty() or compatible_module_ids.has(module_id))
	)

