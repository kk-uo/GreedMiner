class_name WeatherSfx
extends Node

## Weather sounds for a battle (presentation only). BattleMain creates one;
## it listens to WeatherManager (blizzard, ship freeze, boss entrance,
## graveyard lightning, blood moon) and the forest ForestStormController
## (storm warning, rainstorm). Loops fade in/out; nothing here affects play.

const DIR := "res://Assets/Audio/Weather/"
const BLIZZARD := preload(DIR + "blizzard_loop.wav")
const RAIN := preload(DIR + "rain_loop.wav")
const MOON_LOOP := preload(DIR + "blood_moon_loop.wav")
const MOON_START := preload(DIR + "blood_moon_start.wav")
const THUNDER := preload(DIR + "thunder.wav")
const STORM_WARNING := preload(DIR + "storm_warning.wav")
const FREEZE_START := preload(DIR + "freeze_start.wav")
const FREEZE_BREAK := preload(DIR + "freeze_break.wav")
const FREEZE_CLICK := preload(DIR + "freeze_click.wav")
const BOSS_ENTRANCE := preload(DIR + "boss_entrance.wav")
const SILENT_DB: float = -60.0
const FADE_TIME: float = 1.2
const RAIN_FADE_TIME: float = 3.0
const LIGHT_RAIN_DB: float = -30.0
const STORM_RAIN_DB: float = -20.0

var weather: WeatherManager
var _loops: Dictionary = {}
var _targets: Dictionary = {}
var _shots: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_shots = AudioStreamPlayer.new()
	_shots.max_polyphony = 4
	add_child(_shots)
	for key in [&"blizzard", &"rain", &"moon"]:
		var player := AudioStreamPlayer.new()
		player.stream = {&"blizzard": BLIZZARD, &"rain": RAIN, &"moon": MOON_LOOP}[key]
		player.volume_db = SILENT_DB
		add_child(player)
		_loops[key] = player
		_targets[key] = SILENT_DB
	if weather != null:
		weather.weather_changed.connect(_on_weather_changed)
		weather.ship_freeze_changed.connect(_on_freeze_changed)
		weather.freeze_qte_clicked.connect(func(_left: float) -> void: _play(FREEZE_CLICK, -10.0, 0.1))
		weather.boss_entrance_started.connect(func(_d: float) -> void: _play(BOSS_ENTRANCE, -4.0))
		weather.lightning_triggered.connect(func() -> void: _play(THUNDER, -3.0, 0.08))
		weather.blood_moon_started.connect(_on_blood_moon.bind(true))
		weather.blood_moon_ended.connect(_on_blood_moon.bind(false))
	_watch_forest_storms.call_deferred()


## Forest storms live on BattleMain ("ForestStorms") when the planet has them.
func _watch_forest_storms() -> void:
	var storms := get_parent().get_node_or_null("ForestStorms")
	if storms == null:
		return
	_set_loop(&"rain", LIGHT_RAIN_DB)
	storms.connect("storm_warning", func(_s: float) -> void: _play(STORM_WARNING, -12.0))
	storms.connect("storm_started", func(_n: int) -> void:
		_set_loop(&"rain", STORM_RAIN_DB)
		_play(THUNDER, -12.0, 0.1))
	storms.connect("storm_ended", func() -> void: _set_loop(&"rain", LIGHT_RAIN_DB))


func _on_weather_changed(value: int) -> void:
	match value:
		WeatherManager.Weather.BLIZZARD_BOSS:
			_set_loop(&"blizzard", -9.0)
		WeatherManager.Weather.BLIZZARD_NORMAL:
			_set_loop(&"blizzard", -14.0)
		_:
			_set_loop(&"blizzard", SILENT_DB)


func _on_freeze_changed(frozen: bool) -> void:
	_play(FREEZE_START if frozen else FREEZE_BREAK, -6.0)


func _on_blood_moon(active: bool) -> void:
	if active:
		_play(MOON_START, -5.0)
		_set_loop(&"moon", -14.0)
	else:
		_set_loop(&"moon", SILENT_DB)


## Stops every loop at once (battle end).
func stop_all() -> void:
	for key in _loops.keys():
		_targets[key] = SILENT_DB


func _set_loop(key: StringName, volume_db: float) -> void:
	_targets[key] = volume_db
	var player: AudioStreamPlayer = _loops[key]
	if volume_db > SILENT_DB and not player.playing:
		player.volume_db = SILENT_DB
		player.play()


func _play(stream: AudioStream, volume_db: float, pitch_variation: float = 0.0) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _process(delta: float) -> void:
	for key in _loops.keys():
		var player: AudioStreamPlayer = _loops[key]
		if not player.playing:
			continue
		var fade_time := RAIN_FADE_TIME if key == &"rain" else FADE_TIME
		var step := (-SILENT_DB) * delta / fade_time
		player.volume_db = move_toward(player.volume_db, float(_targets[key]), step)
		if player.volume_db <= SILENT_DB + 0.01 and float(_targets[key]) <= SILENT_DB:
			player.stop()
