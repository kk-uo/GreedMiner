class_name WeaponSound
extends AudioStreamPlayer2D

## Small presentation component owned by one weapon. Replace its AudioStream
## in the scene to change a sound without touching combat logic.
@export var continuous: bool = false
@export_range(0.0, 0.15, 0.01) var pitch_variation: float = 0.04

var _requested: bool = false
var _hold_remaining: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if continuous:
		finished.connect(_on_finished)


func _process(delta: float) -> void:
	if not _can_play():
		stop_sound()
		return
	if _hold_remaining > 0.0:
		_hold_remaining = maxf(_hold_remaining - delta, 0.0)
		if _hold_remaining == 0.0:
			stop_sound()


func play_shot() -> void:
	if continuous or stream == null or not _can_play():
		return
	pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	play()


func set_active(active: bool) -> void:
	if not continuous:
		return
	_requested = active and _can_play()
	if _requested:
		if not playing:
			play()
	else:
		if playing:
			stop()


## Extend a short contact or spray sound while attack ticks keep arriving.
func sustain_for(seconds: float) -> void:
	if not continuous or seconds <= 0.0:
		return
	_hold_remaining = maxf(_hold_remaining, seconds)
	set_active(true)


func stop_sound() -> void:
	_requested = false
	_hold_remaining = 0.0
	if playing:
		stop()


func _on_finished() -> void:
	if _requested and _can_play():
		play()


func _can_play() -> bool:
	var weapon := get_parent() as WeaponModule
	return weapon != null and stream != null and not weapon.assembly_mode and not get_tree().paused
