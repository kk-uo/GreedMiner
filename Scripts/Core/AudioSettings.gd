extends Node

## Audio preferences are independent of gameplay progression and save resets.
const SETTINGS_PATH := "user://audio_settings.cfg"
const SAVE_DELAY_SECONDS := 0.3

signal master_volume_changed(percent: int)

var master_volume_percent: int = 100
## Tests can override this before adding a separate instance to the scene tree.
var settings_path: String = SETTINGS_PATH
var _save_timer: Timer
var _dirty: bool = false


func _ready() -> void:
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY_SECONDS
	_save_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_save_timer.timeout.connect(flush)
	add_child(_save_timer)

	var settings := ConfigFile.new()
	if settings.load(settings_path) == OK:
		var saved: Variant = settings.get_value("audio", "master_volume_percent", 100)
		if saved is int or saved is float:
			master_volume_percent = clampi(int(saved), 0, 100)
	_apply_master_volume()


func set_master_volume(percent: int) -> void:
	var clamped := clampi(percent, 0, 100)
	if clamped == master_volume_percent:
		return
	master_volume_percent = clamped
	_apply_master_volume()
	master_volume_changed.emit(master_volume_percent)
	_dirty = true
	_save_timer.start()


func _apply_master_volume() -> void:
	var bus := AudioServer.get_bus_index(&"Master")
	if bus < 0:
		push_warning("AudioSettings: Master audio bus is missing.")
		return
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(float(master_volume_percent) / 100.0, 0.0001)))
	AudioServer.set_bus_mute(bus, master_volume_percent == 0)


## Save after dragging stops; callers may also flush before an immediate quit.
func flush() -> void:
	if not _dirty:
		return
	_save_timer.stop()
	var settings := ConfigFile.new()
	settings.load(settings_path)
	settings.set_value("audio", "master_volume_percent", master_volume_percent)
	if settings.save(settings_path) != OK:
		push_warning("AudioSettings: Could not save audio preference.")
		return
	_dirty = false


func _exit_tree() -> void:
	flush()
