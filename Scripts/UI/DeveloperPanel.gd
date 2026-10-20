class_name DeveloperPanel
extends Control

## Minimal reusable presentation for guarded developer commands.

const SAFE_STARTING_SCENE: String = "res://Scenes/Base/base_main.tscn"

@export var return_to_base_after_reset: bool = true

@onready var balance_label: Label = %BalanceLabel
@onready var currency_selector: OptionButton = %CurrencySelector
@onready var amount_input: LineEdit = %AmountInput
@onready var grant_button: Button = %GrantButton
@onready var unlock_weapons_button: Button = %UnlockWeaponsButton
@onready var unlock_artifacts_button: Button = %UnlockArtifactsButton
@onready var unlock_planets_button: Button = %UnlockPlanetsButton
@onready var reset_button: Button = %ResetButton
@onready var close_button: Button = %CloseButton
@onready var status_label: Label = %StatusLabel
@onready var reset_confirmation: ConfirmationDialog = %ResetConfirmation

var _commands := DeveloperCommands.new()


func _ready() -> void:
	hide()
	currency_selector.clear()
	currency_selector.add_item("Ore")
	currency_selector.set_item_metadata(0, DeveloperCommands.CURRENCY_ORE)
	grant_button.pressed.connect(_on_grant_pressed)
	unlock_weapons_button.pressed.connect(_on_unlock_weapons_pressed)
	unlock_artifacts_button.pressed.connect(_on_unlock_artifacts_pressed)
	unlock_planets_button.pressed.connect(_on_unlock_planets_pressed)
	reset_button.pressed.connect(_on_reset_requested)
	close_button.pressed.connect(close_panel)
	reset_confirmation.confirmed.connect(_on_reset_confirmed)
	if not ResourceManager.stored_ore_changed.is_connected(_on_stored_ore_changed):
		ResourceManager.stored_ore_changed.connect(_on_stored_ore_changed)
	_refresh_balance()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F12:
		if visible:
			close_panel()
		elif DeveloperCommands.is_available():
			open_panel()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()


func open_panel() -> void:
	if not DeveloperCommands.is_available():
		return
	show()
	status_label.text = ""
	_refresh_balance()
	amount_input.grab_focus()


func close_panel() -> void:
	reset_confirmation.hide()
	hide()


func _on_grant_pressed() -> void:
	var currency_id := DeveloperCommands.CURRENCY_ORE
	if currency_selector.selected >= 0:
		currency_id = StringName(currency_selector.get_item_metadata(currency_selector.selected))
	var result := _commands.grant_resource_from_text(currency_id, amount_input.text)
	_show_result(result)
	if bool(result.get("ok", false)):
		amount_input.clear()


func _on_reset_requested() -> void:
	if not DeveloperCommands.is_available():
		_show_result({"ok": false, "message": "Developer Mode is disabled."})
		return
	reset_confirmation.popup_centered()


func _on_unlock_weapons_pressed() -> void:
	_show_result(_commands.unlock_all_weapons())


func _on_unlock_artifacts_pressed() -> void:
	_show_result(_commands.unlock_all_artifacts())


func _on_unlock_planets_pressed() -> void:
	_show_result(_commands.unlock_all_planets())


func _on_reset_confirmed() -> void:
	var result := _commands.reset_all_progress()
	_show_result(result)
	if not bool(result.get("ok", false)):
		return
	if return_to_base_after_reset:
		close_panel()
		get_tree().change_scene_to_file.call_deferred(SAFE_STARTING_SCENE)


func _on_stored_ore_changed(_amount: float) -> void:
	_refresh_balance()


func _refresh_balance() -> void:
	if balance_label != null:
		balance_label.text = "Current Ore: %d" % floori(ResourceManager.stored_ore)


func _show_result(result: Dictionary) -> void:
	status_label.text = String(result.get("message", ""))
	status_label.modulate = Color("8ce8cf") if bool(result.get("ok", false)) else Color("ff8b82")
