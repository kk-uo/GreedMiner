extends Node

## Boss killing blow, style B "cinema" (user pick, every boss): a hit-stop,
## then bullet time (Engine.time_scale) while black letterbox bars slide in,
## the world drains to grey (the death effect itself stays in colour - it is
## drawn above the grey layer), the camera punches toward the boss and shakes,
## then everything eases back. Runs on real time (unaffected by time_scale).
## `keep_camera` leaves the zoom to a following cinematic (RockyFinale).
## Load with preload(); no class_name on purpose.

const HIT_STOP: float = 0.09
const SLOW_UNTIL: float = 1.25
const RECOVER_UNTIL: float = 1.7
const SLOW_SCALE: float = 0.2
const BAR_HEIGHT: float = 0.12
const GREY_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 0.0;
void fragment() {
	vec4 c = texture(screen_texture, SCREEN_UV);
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(c.rgb, vec3(g) * 0.8 + vec3(0.02, 0.02, 0.05), amount), 1.0);
}
"""

static var _active: Node = null

var battle: Node2D
var camera: Camera2D
var focus := Vector2.ZERO
var keep_camera: bool = false

var _start_us: int = 0
var _base_offset := Vector2.ZERO
var _base_zoom := Vector2.ONE
var _base_position := Vector2.ZERO
var _layer: CanvasLayer
var _top: ColorRect
var _bottom: ColorRect
var _flash: ColorRect
var _grey: Node2D
var _grey_material: ShaderMaterial
var _rng := RandomNumberGenerator.new()


## Starts the finisher for a boss that just died at world position `at`.
static func play(boss: Node2D, at: Vector2, keep_camera_for_cinematic: bool = false) -> Node:
	var scene := boss.get_tree().current_scene if boss.is_inside_tree() else null
	if scene == null or not scene is Node2D:
		return null
	if is_instance_valid(_active):
		_active.call("_finish")
	var ship := scene.get_node_or_null("Ship") as Ship
	var node: Node = load("res://Scripts/VFX/BossFinisher.gd").new()
	node.set("battle", scene)
	node.set("camera", ship.world_camera if ship != null else null)
	node.set("focus", at)
	node.set("keep_camera", keep_camera_for_cinematic)
	scene.add_child(node)
	_active = node
	return node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_start_us = Time.get_ticks_usec()
	if is_instance_valid(camera):
		_base_offset = camera.offset
		_base_zoom = camera.zoom
		_base_position = camera.global_position
	_layer = CanvasLayer.new()
	_layer.layer = 60
	add_child(_layer)
	_top = _bar()
	_bottom = _bar()
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_flash)
	# Grey layer in world space, drawn after the ground / ship / enemies
	# (z 0) but under the death effects (z >= 1), so the burst keeps colour.
	_grey = Node2D.new()
	_grey.z_index = 0
	_grey_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = GREY_SHADER
	_grey_material.shader = shader
	_grey.material = _grey_material
	_grey.draw.connect(_draw_grey)
	battle.add_child(_grey)
	Engine.time_scale = 0.0


func _bar() -> ColorRect:
	var bar := ColorRect.new()
	bar.color = Color.BLACK
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(bar)
	return bar


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if is_instance_valid(_grey):
		_grey.queue_free()
	if _active == self:
		_active = null


func _draw_grey() -> void:
	var view := _grey.get_viewport_rect()
	var xf := _grey.get_viewport().get_canvas_transform().affine_inverse()
	var rect := Rect2(xf * view.position, xf.basis_xform(view.size)).grow(200.0)
	_grey.draw_rect(rect, Color.WHITE)


func _process(_delta: float) -> void:
	var t := float(Time.get_ticks_usec() - _start_us) / 1000000.0
	# Time: freeze, bullet time, ease back.
	if t < HIT_STOP:
		Engine.time_scale = 0.0
	elif t < SLOW_UNTIL:
		Engine.time_scale = SLOW_SCALE
	elif t < RECOVER_UNTIL:
		Engine.time_scale = lerpf(SLOW_SCALE, 1.0, smoothstep(SLOW_UNTIL, RECOVER_UNTIL, t))
	else:
		_finish()
		return
	var view := get_viewport().get_visible_rect().size
	var bars_in := smoothstep(HIT_STOP, HIT_STOP + 0.25, t) * (1.0 - smoothstep(SLOW_UNTIL, RECOVER_UNTIL, t))
	var h := view.y * BAR_HEIGHT * bars_in
	_top.position = Vector2.ZERO
	_top.size = Vector2(view.x, h)
	_bottom.position = Vector2(0, view.y - h)
	_bottom.size = Vector2(view.x, h)
	_flash.color = Color(1, 1, 1, 0.65 * (1.0 - smoothstep(0.0, 0.22, t)))
	_grey_material.set_shader_parameter("amount", 0.7 * bars_in)
	_grey.queue_redraw()
	if is_instance_valid(camera):
		var trauma := 1.0 - smoothstep(0.0, 0.9, t)
		var shake := Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * 22.0 * trauma * trauma
		camera.offset = _base_offset + shake
		if not keep_camera:
			var punch := smoothstep(HIT_STOP, 0.45, t) * (1.0 - smoothstep(SLOW_UNTIL, RECOVER_UNTIL, t))
			camera.zoom = _base_zoom * (1.0 + 0.16 * punch)
			camera.global_position = _base_position.lerp(focus, 0.3 * punch)


func _finish() -> void:
	Engine.time_scale = 1.0
	if is_instance_valid(camera):
		camera.offset = _base_offset
		if not keep_camera:
			camera.zoom = _base_zoom
			camera.global_position = _base_position
	queue_free()
