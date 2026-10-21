class_name GiantFrank
extends BasicEnemy

## Presentation hooks; each transition is emitted at most once per encounter.
signal first_death_started
signal grave_awakening_started(points: Array[Vector2])
signal zombies_summoned(count: int)
signal lightning_struck(position: Vector2)
signal resurrection_completed
signal boss_phase_changed(phase: int)
signal boss_final_death

enum Phase { NORMAL, FIRST_DEATH, ENRAGED, FINAL_DEATH }
const ZOMBIE_SCENE: PackedScene = preload("res://Scenes/Enemies/zombie.tscn")
const ZOMBIE_RADIUS := 12.0

@export_group("Resurrection")
@export var grave_provider_path: NodePath = NodePath("../../Battlefield")
@export_range(0.0, 60.0, 0.1) var grave_warning_time := 0.5
@export_range(0.0, 60.0, 0.1) var grave_spawn_time := 1.5
@export_range(0.0, 60.0, 0.1) var lightning_strike_time := 2.5
@export_range(0.0, 60.0, 0.1) var resurrection_finish_time := 3.0
@export var revived_health := 5000.0
@export var revived_speed := 20.0
@export_range(0.0, 1.0, 0.01) var revived_damage_reduction := 0.5

var phase: Phase = Phase.NORMAL
var _elapsed := 0.0
var _awakened := false
var _summoned := false
var _lightning := false
var _grave_points: Array[Vector2] = []

func _die() -> void:
	if phase == Phase.NORMAL:
		phase = Phase.FIRST_DEATH
		_stop_attacking()
		attack_timer.stop()
		set_physics_process(false)
		first_death_started.emit()
		boss_phase_changed.emit(phase)
		return
	if phase != Phase.ENRAGED:
		return
	phase = Phase.FINAL_DEATH
	boss_phase_changed.emit(phase)
	boss_final_death.emit()
	super()

func _process(delta: float) -> void:
	_advance_presentation(delta)
	super(delta)
	if phase != Phase.FIRST_DEATH or not _death_effects_enabled:
		return
	_elapsed += delta
	# Clamp event order so unusual Inspector timing values cannot skip events.
	var warning_at := maxf(0.0, grave_warning_time)
	var spawn_at := maxf(warning_at, grave_spawn_time)
	var lightning_at := maxf(spawn_at, lightning_strike_time)
	var finish_at := maxf(lightning_at, resurrection_finish_time)
	if not _awakened and _elapsed >= warning_at:
		_awakened = true
		_grave_points = _find_grave_points()
		grave_awakening_started.emit(_grave_points.duplicate())
	if not _summoned and _elapsed >= spawn_at:
		_summoned = true
		zombies_summoned.emit(_spawn_zombies())
	if not _lightning and _elapsed >= lightning_at:
		_lightning = true
		lightning_struck.emit(global_position)
	if _elapsed >= finish_at:
		phase = Phase.ENRAGED
		max_health = revived_health
		_current_health = revived_health
		move_speed = revived_speed
		damage_reduction = revived_damage_reduction
		set_physics_process(true)
		health_changed.emit(_current_health, max_health)
		boss_phase_changed.emit(phase)
		resurrection_completed.emit()

## Providers return world-space points; their array index identifies a grave
## for this event. Production Battlefield already implements this interface.
func _find_grave_points() -> Array[Vector2]:
	return GraveSummoner.points(get_node_or_null(grave_provider_path))

func _spawn_zombies() -> int:
	return GraveSummoner.spawn(
		get_node_or_null(grave_provider_path), get_parent() as Node2D,
		target_ship as Ship, ZOMBIE_SCENE, _grave_points, &"giant_frank_resurrection"
	)

func _get_visual_radius() -> float:
	return 76.0

func _draw() -> void:
	var state := UndeadVisual.FrankState.NORMAL
	if phase == Phase.FIRST_DEATH:
		state = UndeadVisual.FrankState.DOWN
	elif phase == Phase.ENRAGED or phase == Phase.FINAL_DEATH:
		state = UndeadVisual.FrankState.ENRAGED
	var step := 0.0 if (_is_attacking or phase == Phase.FIRST_DEATH) else sin(_anim_time * TAU * 0.6)
	UndeadVisual.draw_frank(self, _facing, step, UndeadVisual.attack_amount(_attack_pose_time),
			_is_flashing(), _anim_time, state)


# ==========================================
# Presentation only (UndeadVisual, style A "classic Frankenstein")
# ==========================================

const RESURRECTION_FX := preload("res://Scripts/VFX/FrankResurrectionFx.gd")
var _anim_time: float = 0.0
var _attack_pose_time: float = 0.0


func _ready() -> void:
	super()
	# First death: the screen goes black around the fallen Frank, a huge bolt
	# strikes him (lightning_struck) and he rises again (FrankResurrectionFx).
	first_death_started.connect(func() -> void:
		if _death_effects_enabled and get_parent() != null:
			RESURRECTION_FX.play(get_parent(), self))


func _on_attack_timer_timeout() -> void:
	super()
	if _is_attacking:
		_attack_pose_time = UndeadVisual.ATTACK_POSE_TIME


func _advance_presentation(delta: float) -> void:
	_anim_time += delta
	_attack_pose_time = maxf(_attack_pose_time - delta, 0.0)
