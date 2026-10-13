extends Node2D

## Controls navigation from the combat scene back to the assembly base.

const BASE_SCENE_PATH: String = "res://Scenes/base_main.tscn"

@onready var return_to_base_button: Button = $BattleUI/ReturnToBaseButton


func _ready() -> void:
	var callback := Callable(self, "_on_return_to_base_button_pressed")
	if not return_to_base_button.pressed.is_connected(callback):
		return_to_base_button.pressed.connect(callback)


## Returns to BaseMain while preserving the shared ShipLoadout.
func _on_return_to_base_button_pressed() -> void:
	get_tree().change_scene_to_file(BASE_SCENE_PATH)
