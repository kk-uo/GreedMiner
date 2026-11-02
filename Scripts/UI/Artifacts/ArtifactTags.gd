extends RefCounted

## Category tags for magic artifacts, used by the hangar storage picker's tag
## tabs (StoragePicker). One artifact can carry several tags. A new artifact
## without an entry here shows under "OTHER" until it is added.
## Load with preload(); no class_name on purpose.

## Tab order. English msgids; Chinese in Translations/zh_CN.po.
const ORDER: Array[String] = ["DAMAGE", "FIRE RATE", "REACH", "PROJECTILES", "SPLASH", "CONTROL", "SHIP", "OTHER"]

const TAGS := {
	&"black_stone": ["DAMAGE"],
	&"red_stone": ["DAMAGE"],
	&"goblin_tooth": ["DAMAGE"],
	&"red_crystal": ["SPLASH", "DAMAGE"],
	&"angry_stone": ["SPLASH"],
	&"necronomicon": ["SPLASH"],
	&"goblin_flag": ["FIRE RATE"],
	&"goblin_horn": ["FIRE RATE"],
	&"goblin_scope": ["REACH"],
	&"snow_monster_eyeball": ["REACH"],
	&"dragon_wing": ["REACH"],
	&"ghost_bullet": ["PROJECTILES"],
	&"bat_eyeball": ["PROJECTILES"],
	&"demon_prism": ["PROJECTILES"],
	&"frost_breath": ["CONTROL"],
	&"zombie_arm": ["PROJECTILES"],
	&"blizzard_bottle": ["CONTROL", "SHIP"],
	&"true_ice": ["CONTROL"],
	&"stone_heart": ["SHIP"],
	&"goblin_wheel": ["SHIP"],
}


static func tags_for(artifact_id: StringName) -> Array[String]:
	var result: Array[String] = []
	for tag in TAGS.get(artifact_id, ["OTHER"]):
		result.append(String(tag))
	return result
