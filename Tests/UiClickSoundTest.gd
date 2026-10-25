extends Control

## UiClickSound decides what counts as a click target (buttons and
## pointing-hand custom controls, not disabled buttons or plain panels).
const UI_CLICK := preload("res://Scripts/Audio/UiClickSound.gd")
var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var button := Button.new()
	button.text = "OK"
	add_child(button)
	var label := Label.new()
	button.add_child(label)
	var disabled := Button.new()
	disabled.disabled = true
	add_child(disabled)
	var card := PanelContainer.new()
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(card)
	var card_icon := Control.new()
	card.add_child(card_icon)
	var plain := Panel.new()
	add_child(plain)
	_check(UI_CLICK.is_clickable(button), "enabled button is clickable")
	_check(UI_CLICK.is_clickable(label), "label inside a button counts as the button")
	_check(not UI_CLICK.is_clickable(disabled), "disabled button stays silent")
	_check(UI_CLICK.is_clickable(card), "pointing-hand custom card is clickable")
	_check(UI_CLICK.is_clickable(card_icon), "child of a pointing-hand card is clickable")
	_check(not UI_CLICK.is_clickable(plain), "plain panel is not clickable")
	_check(not UI_CLICK.is_clickable(null), "nothing hovered is not clickable")
	button.hide()
	_check(not UI_CLICK.is_clickable(button), "hidden button is not clickable")
	var click := get_node_or_null(^"/root/UiClickSound")
	_check(click != null, "UiClickSound autoload is registered")
	if click != null:
		var player := click.get_child(0) as AudioStreamPlayer
		_check(player != null and player.stream != null, "click player has the pop stream")
	if failures.is_empty():
		print("UI_CLICK_SOUND_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("UI_CLICK_SOUND_TEST: " + failure)
		print("UI_CLICK_SOUND_TEST: FAIL (%d failures)" % failures.size())
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
