extends Node2D

## Moving highlights on the Volcanic Planet's lava streams: bright streaks
## drift downstream and the hot core flickers. The streams themselves (glow,
## crust banks, base colour) are baked into the Battlefield map; this layer
## only draws the animated part, as one triangle batch per frame.
## Created by Battlefield; load with preload(), no class_name on purpose.

## Streak travel speed along the stream (px/s), streak period and length.
const FLOW_SPEED: float = 26.0
const STREAK_PERIOD: float = 38.0
const STREAK_LENGTH: float = 13.0
const HOT := Color("FFB347")
const CORE := Color("FFE9A8")

var _streams: Array[Dictionary] = []
var _time: float = 0.0
var _pen := MeshBatch2D.new()


func set_streams(streams: Array[Dictionary]) -> void:
	_streams.clear()
	for stream in streams:
		var points: PackedVector2Array = stream["points"]
		var distances := PackedFloat32Array([0.0])
		for index in range(1, points.size()):
			distances.append(distances[index - 1] + points[index - 1].distance_to(points[index]))
		_streams.append({"points": points, "widths": stream["widths"], "distances": distances})
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var shift: float = _time * FLOW_SPEED
	for stream in _streams:
		var points: PackedVector2Array = stream["points"]
		var widths: PackedFloat32Array = stream["widths"]
		var distances: PackedFloat32Array = stream["distances"]
		var count := points.size()
		var total: float = distances[count - 1]
		for index in range(count - 1):
			var t: float = float(index) / float(count - 1)
			# Highlights fade out where the tail has cooled.
			var heat: float = 1.0 - smoothstep(0.5, 0.95, t)
			if heat <= 0.0:
				continue
			var w: float = widths[index]
			var a: Vector2 = points[index]
			var b: Vector2 = points[index + 1]
			var flicker: float = 0.75 + 0.25 * sin(_time * 3.1 + distances[index] * 0.05)
			_pen.draw_line(a, b, Color(HOT, 0.55 * heat * flicker), maxf(w * 0.45, 1.0))
			# Streak phase at this segment's start and end.
			var from_phase: float = fposmod(distances[index] - shift, STREAK_PERIOD)
			if from_phase < STREAK_LENGTH:
				var segment: float = distances[index + 1] - distances[index]
				var end_k: float = clampf((STREAK_LENGTH - from_phase) / maxf(segment, 0.001), 0.0, 1.0)
				_pen.draw_line(a, a.lerp(b, end_k), Color(CORE, 0.9 * heat), maxf(w * 0.4, 1.0))
		# Vent bubbles.
		if total > 0.0:
			var pulse: float = 0.5 + 0.5 * sin(_time * 2.4 + total)
			_pen.draw_circle(points[0] + Vector2(-1.5, -1.5), 1.6 + 1.6 * pulse, Color(CORE, 0.85))
	_pen.flush_to(self)
