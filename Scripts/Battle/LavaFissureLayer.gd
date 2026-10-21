extends Node2D

## Draws the Volcanic Planet's lava rifts (LavaFissureArt). The static layers
## are baked into one mesh; the hot core is baked into two meshes that pulse
## out of step, so the glow seems to flow along the rift. Presentation only.
## Load with preload(); no class_name on purpose.

const ART := preload("res://Scripts/Battle/LavaFissureArt.gd")

var _static_mesh: ArrayMesh
var _core_meshes: Array = [null, null]
var _time: float = 0.0


func set_fissures(fissures: Array) -> void:
	_static_mesh = _bake(func(pen: Object) -> void:
		for fissure in fissures:
			ART.draw_static(pen, fissure))
	for phase in range(2):
		_core_meshes[phase] = _bake(func(pen: Object) -> void:
			for fissure in fissures:
				ART.draw_core(pen, fissure, phase))
	queue_redraw()


func _bake(paint: Callable) -> ArrayMesh:
	var batch := MeshBatch2D.new()
	paint.call(batch)
	return batch.build() if batch.get_vertex_count() > 0 else null


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if _static_mesh != null:
		draw_mesh(_static_mesh, null)
	for phase in range(2):
		if _core_meshes[phase] != null:
			var pulse := 0.5 + 0.5 * sin(_time * 2.4 + PI * float(phase))
			draw_mesh(_core_meshes[phase], null, Transform2D.IDENTITY, Color(1, 1, 1, 0.55 + 0.45 * pulse))
