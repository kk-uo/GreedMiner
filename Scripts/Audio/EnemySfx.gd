class_name EnemySfx
extends Node2D

## Shared, pooled one-shot world sounds (enemy attacks / deaths, mining,
## QTE, ore pickups), so a crowd
## of enemies never owns hundreds of audio players. Positional
## (AudioStreamPlayer2D, heard from the battle camera). Each stream is rate
## limited: at most MAX_PER_STREAM copies at once and none closer than
## MIN_GAP_MSEC, so 30 pebbles dying in one frame stay one clean crunch.
## Presentation only. Usage: EnemySfx.play(self, STREAM, volume_db)

const POOL_SIZE: int = 18
const MAX_PER_STREAM: int = 3
const MIN_GAP_MSEC: int = 45

static var _instance: EnemySfx

var _players: Array[AudioStreamPlayer2D] = []
var _last_played: Dictionary = {}


## Plays `stream` at `source`'s position (a Node2D, or a Vector2 world point).
static func play(source: Variant, stream: AudioStream, volume_db: float = -10.0, pitch_variation: float = 0.08, pitch: float = 1.0) -> void:
	if stream == null:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var at := Vector2.ZERO
	if source is Node2D:
		if not is_instance_valid(source):
			return
		at = (source as Node2D).global_position
	elif source is Vector2:
		at = source
	if not is_instance_valid(_instance) or _instance.get_parent() != tree.current_scene:
		_instance = EnemySfx.new()
		_instance.name = "EnemySfx"
		tree.current_scene.add_child(_instance)
	_instance._play(at, stream, volume_db, pitch_variation, pitch)


func _ready() -> void:
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer2D.new()
		player.max_distance = 2600.0
		player.attenuation = 1.4
		add_child(player)
		_players.append(player)


func _play(at: Vector2, stream: AudioStream, volume_db: float, pitch_variation: float, pitch: float = 1.0) -> void:
	var now := Time.get_ticks_msec()
	var key := stream.get_instance_id()
	if now - int(_last_played.get(key, -100000)) < MIN_GAP_MSEC:
		return
	var same := 0
	var free_player: AudioStreamPlayer2D = null
	var oldest: AudioStreamPlayer2D = null
	var oldest_pos := -1.0
	for player in _players:
		if player.playing:
			if player.stream == stream:
				same += 1
			var pos := player.get_playback_position()
			if pos > oldest_pos:
				oldest_pos = pos
				oldest = player
		elif free_player == null:
			free_player = player
	if same >= MAX_PER_STREAM:
		return
	var player := free_player if free_player != null else oldest
	if player == null:
		return
	_last_played[key] = now
	player.stop()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch * (1.0 + randf_range(-pitch_variation, pitch_variation))
	player.global_position = at
	player.play()
