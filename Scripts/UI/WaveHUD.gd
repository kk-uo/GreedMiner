class_name WaveHUD
extends VBoxContainer

## Minimal signal-driven wave status display.

@onready var wave_label: Label = $WaveLabel
@onready var status_label: Label = $StatusLabel
@onready var remaining_label: Label = $RemainingLabel


func show_preparation(wave_number: int, total_waves: int, duration: float) -> void:
	wave_label.text = "WAVE  %d / %d" % [wave_number, total_waves]
	status_label.text = "PREP  %d" % ceili(duration)
	_set_status_visible(true)


func update_preparation(seconds_remaining: int) -> void:
	status_label.text = "PREP  %d" % seconds_remaining


func show_wave(wave_number: int, total_waves: int, boss_wave: bool) -> void:
	wave_label.text = "WAVE  %d / %d" % [wave_number, total_waves]
	# Normal waves show no status line; only the boss wave is called out.
	status_label.text = "BOSS WAVE"
	_set_status_visible(boss_wave)


func update_remaining(remaining_count: int) -> void:
	remaining_label.text = "ENEMIES  %d" % remaining_count


## Development-only state for a deliberately reserved, unconfigured boss wave.
func show_configuration_blocked(wave_number: int, message: String) -> void:
	wave_label.text = "WAVE  %d  //  DEVELOPMENT" % wave_number
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
