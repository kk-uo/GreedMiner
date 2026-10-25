class_name DeveloperPanel
extends Control

## Minimal reusable presentation for guarded developer commands.

const SAFE_STARTING_SCENE: String = "res://Scenes/Base/base_main.tscn"

@export var return_to_base_after_reset: bool = true
## Combat exposes only the reversible speed control, not progression commands.
@export var battle_mode: bool = false

@onready var balance_label: Label = %BalanceLabel
@onready var currency_selector: OptionButton = %CurrencySelector
@onready var amount_input: LineEdit = %AmountInput
@onready var grant_button: Button = %GrantButton
@onready var unlock_weapons_button: Button = %UnlockWeaponsButton
@onready var unlock_artifacts_button: Button = %UnlockArtifactsButton
@onready var unlock_planets_button: Button = %UnlockPlanetsButton
@onready var unlock_fusion_button: Button = %UnlockFusionButton
@onready var reset_button: Button = %ResetButton
@onready var close_button: Button = %CloseButton
@onready var status_label: Label = %StatusLabel
@onready var reset_confirmation: ConfirmationDialog = %ResetConfirmation
@onready var speed_button: Button = %SpeedButton

var _commands := DeveloperCommands.new()


func _ready() -> void:
	hide()
	_apply_localized_text()
	currency_selector.clear()
	currency_selector.add_item(tr("Ore"))
	currency_selector.set_item_metadata(0, DeveloperCommands.CURRENCY_ORE)
	grant_button.pressed.connect(_on_grant_pressed)
	unlock_weapons_button.pressed.connect(_on_unlock_weapons_pressed)
	unlock_artifacts_button.pressed.connect(_on_unlock_artifacts_pressed)
	unlock_planets_button.pressed.connect(_on_unlock_planets_pressed)
	unlock_fusion_button.pressed.connect(_on_unlock_fusion_pressed)
	reset_button.pressed.connect(_on_reset_requested)
	close_button.pressed.connect(close_panel)
	reset_confirmation.confirmed.connect(_on_reset_confirmed)
	speed_button.visible = battle_mode
	speed_button.pressed.connect(_on_speed_pressed)
	if battle_mode:
		for item in [balance_label, currency_selector, amount_input, grant_button, unlock_weapons_button, unlock_artifacts_button, unlock_planets_button, unlock_fusion_button, reset_button]:
			item.hide()
		_refresh_speed_button()
	if not ResourceManager.stored_ore_changed.is_connected(_on_stored_ore_changed):
		ResourceManager.stored_ore_changed.connect(_on_stored_ore_changed)
	_refresh_balance()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_apply_localized_text()
		_refresh_balance()
		_refresh_speed_button()


func _apply_localized_text() -> void:
	$Center/Panel/Content/Title.text = tr("DEVELOPER MODE")
	$Center/Panel/Content/Hint.text = tr("Playtest tools  •  F12 to close")
	amount_input.placeholder_text = tr("Non-negative whole amount")
	grant_button.text = tr("Grant Resources")
	speed_button.text = tr("Battle speed: %.0f×") % 1.0
	unlock_weapons_button.text = tr("Unlock All Weapons")
	unlock_artifacts_button.text = tr("Unlock All Magic Artifacts")
	unlock_planets_button.text = tr("Unlock All Planets")
	unlock_fusion_button.text = tr("Unlock Weapon Fusion")
	reset_button.text = tr("Reset All Progress")
	close_button.text = tr("Close")
	reset_confirmation.title = tr("Reset All Progress?")
	reset_confirmation.dialog_text = tr("This permanently resets currencies, research, unlocks, magic artifacts, and the ship loadout to new-game defaults.")
	reset_confirmation.ok_button_text = tr("Reset Progress")
	reset_confirmation.cancel_button_text = tr("Cancel")
	if currency_selector.item_count > 0:
		currency_selector.set_item_text(0, tr("Ore"))


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
	if battle_mode:
		_refresh_speed_button()
	if not battle_mode:
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


func _on_unlock_fusion_pressed() -> void:
	_show_result(_commands.unlock_weapon_fusion())

func _on_speed_pressed() -> void:
	var controller := get_tree().get_first_node_in_group("developer_battle_speed") as DeveloperBattleSpeed
	if controller == null or not controller.set_speed(2.0 if controller.selected_speed == 1.0 else 1.0):
		_show_result({"ok": false, "message": "Battle speed is unavailable."})
		return
	_refresh_speed_button()

func _refresh_speed_button() -> void:
	var controller := get_tree().get_first_node_in_group("developer_battle_speed") as DeveloperBattleSpeed
	if speed_button != null:
		speed_button.disabled = controller == null or not DeveloperCommands.is_available()
		speed_button.text = tr("Battle speed: %.0f×") % (controller.selected_speed if controller != null else 1.0)


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
		balance_label.text = tr("Current Ore: %d") % floori(ResourceManager.stored_ore)


func _show_result(result: Dictionary) -> void:
	var message_key := String(result.get("message_key", result.get("message", "")))
	var translated := tr(message_key)
	var message_args: Array = result.get("message_args", [])
	status_label.text = translated % message_args if not message_args.is_empty() else translated
	status_label.modulate = Color("8ce8cf") if bool(result.get("ok", false)) else Color("ff8b82")
