extends Node

## Small versioned persistence service for base progression only.
## Gameplay systems own their sections and never overwrite unrelated data.

const DEFAULT_SAVE_PATH: String = "user://greedminer_progression.json"
const SAVE_VERSION: int = 1

var save_path: String = DEFAULT_SAVE_PATH
var _data: Dictionary = {}


func _ready() -> void:
	reload_from_disk()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not _data.is_empty():
		# State-changing managers save immediately. This final flush protects the
		# shared progression document when the native window is closed directly.
		save_to_disk()


func reload_from_disk() -> void:
	_data = {"version": SAVE_VERSION}
	if not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_warning("ProgressionStore: Could not open save file for reading.")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_data = (parsed as Dictionary).duplicate(true)
		_data["version"] = int(_data.get("version", SAVE_VERSION))
	else:
		push_warning("ProgressionStore: Save data is invalid; safe defaults are used.")


func get_section(section_id: StringName) -> Dictionary:
	var section: Variant = _data.get(String(section_id), {})
	return (section as Dictionary).duplicate(true) if section is Dictionary else {}


func set_section(section_id: StringName, value: Dictionary) -> bool:
	_data[String(section_id)] = value.duplicate(true)
	return save_to_disk()


func save_to_disk() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("ProgressionStore: Could not open save file for writing.")
		return false
	file.store_string(JSON.stringify(_data, "\t"))
	return true


## Replaces only persistent player progression with a fresh save document.
## Resource definitions, project settings, scenes, and source files are never touched.
## The previous in-memory data is restored if the new save cannot be written.
func reset_all_progress() -> bool:
	var previous_data := _data.duplicate(true)
	_data = {"version": SAVE_VERSION}
	if save_to_disk():
		return true
	_data = previous_data
	return false


## Test hook allowing isolated persistence without touching the normal save.
func set_save_path_for_testing(path: String) -> void:
	save_path = path
	reload_from_disk()


func restore_default_save_path() -> void:
	save_path = DEFAULT_SAVE_PATH
	reload_from_disk()
