class_name ModuleIcon
extends Control

## Shows a live, inert copy of a module scene as its UI icon, so icons always
## match the in-game art without any image files.

var _module_id: StringName = &""
var _preview: Node2D = null
var _icon_scale: float = 0.7


func setup(module_id: StringName, box_size: float, icon_scale: float) -> void:
	_module_id = module_id
	_icon_scale = icon_scale
	custom_minimum_size = Vector2.ONE * box_size
	size = custom_minimum_size
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_inside_tree():
		_rebuild()


func _ready() -> void:
	resized.connect(_center_preview)
	_rebuild()


func _draw() -> void:
	Palette.draw_rounded_rect(self, Rect2(Vector2.ZERO, size), 8.0, Palette.UI_PANEL)


func _rebuild() -> void:
	if _preview != null:
		_preview.queue_free()
		_preview = null
	var scene := ModuleCatalog.get_scene(_module_id)
	if scene == null:
		return
	var module := scene.instantiate() as Node2D
	if module == null:
		return
	# Inert preview: weapons never fire and drills never mine.
	if module is WeaponModule:
		(module as WeaponModule).assembly_mode = true
	if module is MiningModule:
		(module as MiningModule).mining_enabled = false
	# Shields must not act from the UI either (a preview Regeneration would
	# otherwise heal the real ship and spawn healing particles over it).
	if module is ShieldModule:
		(module as ShieldModule).set_module_active(false)
	module.scale = Vector2.ONE * _icon_scale
	_preview = module
	add_child(module)
	var turret := module.get_node_or_null("Turret") as Node2D
	if turret != null:
		turret.rotation = -PI * 0.25
	_center_preview()


func _center_preview() -> void:
	if _preview != null:
		# Nudge left a little: turrets point toward the upper right.
		_preview.position = size * 0.5 - Vector2(2.0, -2.0) * _icon_scale
