extends SceneTree

const ArtifactSort := preload("res://Scripts/Artifacts/MagicArtifactSort.gd")
const Definition := preload("res://Scripts/Artifacts/MagicArtifactDefinition.gd")


func _initialize() -> void:
	var items: Array[MagicArtifactDefinition] = [
		_make(&"common_chest", "Common", true, 0),
		_make(&"epic_chest", "Epic", true, 0),
		_make(&"rare_world", "Rare", false, 1),
		_make(&"epic_world", "Epic", false, 1),
		_make(&"epic_boss", "Epic", false, 0),
		_make(&"legendary_chest", "Legendary", true, 0),
		_make(&"common_boss", "Common", false, 0),
	]
	items.sort_custom(ArtifactSort.less_by_rarity_and_source)
	var actual: Array[StringName] = []
	for definition in items:
		actual.append(definition.artifact_id)
	var expected: Array[StringName] = [
		&"legendary_chest", &"epic_boss", &"epic_world", &"epic_chest",
		&"rare_world", &"common_boss", &"common_chest",
	]
	if actual != expected:
		push_error("Artifact default sort incorrect: %s" % [actual])
		quit(1)
		return
	var red_crystal: MagicArtifactDefinition = preload("res://Resources/Artifacts/RedCrystal.tres")
	var angry_stone: MagicArtifactDefinition = preload("res://Resources/Artifacts/AngryStone.tres")
	var stone_heart: MagicArtifactDefinition = preload("res://Resources/Artifacts/StoneHeart.tres")
	if red_crystal.get_acquisition_method() != Definition.AcquisitionMethod.WORLD \
		or angry_stone.get_acquisition_method() != Definition.AcquisitionMethod.MINING_CHEST \
		or stone_heart.get_acquisition_method() != Definition.AcquisitionMethod.BOSS:
		push_error("Artifact acquisition method data incorrect")
		quit(1)
		return
	print("ARTIFACT SORTING TEST PASSED")
	quit(0)


func _make(id: StringName, rarity: String, chest: bool, method: int) -> MagicArtifactDefinition:
	var definition: MagicArtifactDefinition = Definition.new()
	definition.artifact_id = id
	definition.rarity = rarity
	definition.mining_chest_reward = chest
	definition.acquisition_method = method
	return definition
