class_name MiningQteConfig
extends Resource

## Balancing values for mining QTEs (Resources/Mining/MiningQteConfig.tres).
## Every timing and reward number used by the QTE system lives here.
## All "reward seconds" are multiplied by the triggering module's effective
## ore per second (MiningModule.get_effective_ore_per_second()).

@export_group("Triggering")
## Seconds after the battle starts before the first global check.
@export var initial_delay: float = 30.0
## Seconds between global checks. The timer keeps running during an event.
@export var check_interval: float = 30.0
## Chance per global check to start an event (1 = guaranteed every check).
## One roll for the whole ship: more Mining Modules never mean more events.
@export_range(0.0, 1.0, 0.01) var chance_per_check: float = 1.0
## When a check lands while an event is still active: true = start the next
## event as soon as that one ends (at most one waiting, never stacked);
## false = skip that check.
@export var start_when_free: bool = true
## Extra quiet time after an event finishes before the next check (0 = none).
@export var cooldown_after_event: float = 0.0
## Relative weights of the three event types.
@export var weight_ore_burst: float = 45.0
@export var weight_precision: float = 40.0
@export var weight_salvage: float = 15.0
## Global limit of simultaneous QTEs. The design calls for exactly 1.
@export var max_concurrent_events: int = 1

@export_group("Timing")
## Lifetime of a yellow "!" marker (Ore Burst, Precision Mining).
@export var marker_lifetime: float = 6.0
## Lifetime of a salvage chest waiting to be opened.
@export var salvage_lifetime: float = 30.0
## Precision Mining warning before the skill check starts.
@export var precision_warning_duration: float = 2.0

@export_group("Ore Burst")
## Length of the rapid-clicking phase after the "!" is clicked.
@export var burst_duration: float = 5.0
## Minimum seconds between two valid clicks (faster clicks are ignored).
@export var burst_click_cooldown: float = 0.1
## Each valid click pays this many seconds of the module's production.
@export var burst_reward_seconds_per_click: float = 5.0

@export_group("Precision Mining (arc)")
## Angular length of the arc track; the needle crosses it once.
@export var arc_sweep_degrees: float = 240.0
## Needle speed along the arc in degrees per second.
@export var needle_speed_degrees: float = 240.0
## Success region size in degrees (green).
@export var success_zone_degrees: float = 60.0
## Perfect region size in degrees (gold, centred inside the success region).
@export var perfect_zone_degrees: float = 12.0
## Earliest / latest start of the success region, in degrees from the start
## of the arc (clamped so the region always fits on the arc).
@export var zone_min_start_degrees: float = 60.0
@export var zone_max_start_degrees: float = 175.0
## Rewards in seconds of production. A miss (or no input) after activating
## still pays the failed amount; ignoring the "!" pays nothing.
@export var precision_perfect_reward_seconds: float = 120.0
@export var precision_success_reward_seconds: float = 60.0
@export var precision_failed_reward_seconds: float = 10.0

@export_group("Salvage Chest")
## Salvage Chest reward = effective ore per second × this.
@export var reward_seconds: float = 100.0
## Chance of an artifact while an unowned chest artifact exists.
@export_range(0.0, 1.0, 0.01) var salvage_artifact_chance: float = 0.7
