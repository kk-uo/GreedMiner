extends RefCounted

## Permanent base decorations earned in battle (saved in ProgressionStore
## section "base_trophies"). Currently: &"snowman" - defeating the Frozen
## Planet boss (Mega Monster) puts a snowman in the hold.
## Load with preload(); no class_name on purpose.

const SAVE_SECTION: StringName = &"base_trophies"


static func has_trophy(trophy_id: StringName) -> bool:
	return bool(ProgressionStore.get_section(SAVE_SECTION).get(String(trophy_id), false))


static func grant(trophy_id: StringName) -> void:
	if has_trophy(trophy_id):
		return
	var data := ProgressionStore.get_section(SAVE_SECTION)
	data[String(trophy_id)] = true
	ProgressionStore.set_section(SAVE_SECTION, data)
