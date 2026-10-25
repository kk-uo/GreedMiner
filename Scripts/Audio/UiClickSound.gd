extends Node

## Autoload: plays the UI click (user pick "B soft pop") whenever the player
## clicks something clickable - any enabled BaseButton, or a custom control
## that shows the pointing-hand cursor (cards, slots, planet picks...).
## Keyboard / gamepad activation of a focused button clicks too.
## Presentation only; nothing else listens to this.
const CLICK := preload("res://Assets/Audio/UI/click_pop.wav")
## How many ancestors of the hovered control may make it clickable (a label
## inside a card still counts as clicking the card).
const ANCESTOR_DEPTH: int = 4
const MIN_INTERVAL_MSEC: int = 40

var enabled: bool = true
var _player: AudioStreamPlayer
var _last_click_msec: int = -1000


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.stream = CLICK
	_player.volume_db = -9.0
	_player.max_polyphony = 3
	add_child(_player)


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	var mouse := event as InputEventMouseButton
	if mouse != null:
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT and is_clickable(get_viewport().gui_get_hovered_control()):
			play()
		return
	if event.is_action_pressed(&"ui_accept") and not event.is_echo():
		var focused := get_viewport().gui_get_focus_owner()
		if focused is BaseButton and not (focused as BaseButton).disabled:
			play()


func play() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_click_msec < MIN_INTERVAL_MSEC:
		return
	_last_click_msec = now
	_player.pitch_scale = randf_range(0.97, 1.03)
	_player.play()


static func is_clickable(control: Control) -> bool:
	var node: Node = control
	for _depth in range(ANCESTOR_DEPTH + 1):
		var c := node as Control
		if c == null or not c.is_visible_in_tree():
			return false
		if c is BaseButton:
			return not (c as BaseButton).disabled
		if c.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND:
			return true
		node = c.get_parent()
	return false
