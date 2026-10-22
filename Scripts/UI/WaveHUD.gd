class_name WaveHUD
extends VBoxContainer

## Minimal signal-driven wave status display.

@onready var wave_label: Label = $WaveRow/WaveLabel
@onready var status_label: Label = $StatusLabel
@onready var remaining_label: Label = $EnemyRow/RemainingLabel

var _wave_number := 0
var _total_waves := 0
var _remaining := 0
var _preparation_seconds := 0
var _mode := &""
var _blocked_message := ""


func _ready() -> void:
	LanguageManager.language_changed.connect(_on_language_changed)


func _on_language_changed(_locale: StringName) -> void:
	match _mode:
		&"preparation":
			show_preparation(_wave_number, _total_waves, float(_preparation_seconds))
		&"wave":
			show_wave(_wave_number, _total_waves, status_label.visible)
		&"blocked":
			show_configuration_blocked(_wave_number, _blocked_message)
	update_remaining(_remaining)


func show_preparation(wave_number: int, total_waves: int, duration: float) -> void:
	_mode = &"preparation"
	_wave_number = wave_number
	_total_waves = total_waves
	_preparation_seconds = ceili(duration)
	wave_label.text = "%d / %d" % [wave_number, total_waves]
	status_label.text = tr("PREP  %d") % ceili(duration)
	_set_status_visible(true)


func update_preparation(seconds_remaining: int) -> void:
	_preparation_seconds = seconds_remaining
	status_label.text = tr("PREP  %d") % seconds_remaining


func show_wave(wave_number: int, total_waves: int, boss_wave: bool) -> void:
	_mode = &"wave"
	_wave_number = wave_number
	_total_waves = total_waves
	wave_label.text = "%d / %d" % [wave_number, total_waves]
	# Normal waves show no status line; only the boss wave is called out.
	status_label.text = tr("BOSS WAVE")
	_set_status_visible(boss_wave)


func update_remaining(remaining_count: int) -> void:
	_remaining = remaining_count
	remaining_label.text = str(remaining_count)


## Development-only state for a deliberately reserved, unconfigured boss wave.
func show_configuration_blocked(wave_number: int, message: String) -> void:
	_mode = &"blocked"
	_wave_number = wave_number
	_blocked_message = message
	wave_label.text = "%d" % wave_number
	status_label.text = message.to_upper()
	_set_status_visible(true)


## Shows or hides the status line and shrinks the panel to fit.
func _set_status_visible(shown: bool) -> void:
	if status_label.visible == shown:
		return
	status_label.visible = shown
	_fit_panel_height.call_deferred()


## Keeps the panel's width and shrinks/grows only its height to the content.
func _fit_panel_height() -> void:
	var panel := get_parent() as Control
	if panel != null:
		panel.offset_bottom = panel.offset_top + panel.get_combined_minimum_size().y
