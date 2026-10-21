extends Node

## Language preferences are independent of gameplay progression and resets.
const SETTINGS_PATH := "user://language_settings.cfg"
const SUPPORTED := [&"en", &"zh_CN"]

signal language_changed(locale: StringName)

var _transition_active := false
var _fade: ColorRect


func _ready() -> void:
	var settings := ConfigFile.new()
	var locale := &"en"
	if settings.load(SETTINGS_PATH) == OK:
		var saved := StringName(settings.get_value("language", "locale", "en"))
		if saved in SUPPORTED:
			locale = saved
	TranslationServer.set_locale(locale)
	var layer := CanvasLayer.new()
	layer.layer = 1000
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)


## Switch at full black; the overlay also runs while the battle is paused.
func request_language(locale: StringName) -> bool:
	if locale not in SUPPORTED or _transition_active:
		return false
	if TranslationServer.get_locale() == String(locale):
		return true
	_transition_active = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	# An unbound SceneTree tween keeps running when the battle tree is paused.
	var tween := get_tree().create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade, "color:a", 1.0, 0.2)
	tween.tween_callback(func() -> void: set_language(locale))
	tween.tween_interval(0.05)
	tween.tween_property(_fade, "color:a", 0.0, 0.2)
	tween.tween_callback(func() -> void:
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_transition_active = false
	)
	return true


func set_language(locale: StringName) -> bool:
	if locale not in SUPPORTED:
		return false
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	settings.set_value("language", "locale", String(locale))
	if settings.save(SETTINGS_PATH) != OK:
		push_warning("LanguageManager: Could not save language preference.")
		return false
	TranslationServer.set_locale(locale)
	# Refresh existing controls and custom-drawn labels without reloading gameplay.
	get_tree().root.propagate_notification(NOTIFICATION_TRANSLATION_CHANGED)
	_redraw_canvas_items(get_tree().root)
	language_changed.emit(locale)
	return true


func _redraw_canvas_items(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).queue_redraw()
	for child in node.get_children():
		_redraw_canvas_items(child)
