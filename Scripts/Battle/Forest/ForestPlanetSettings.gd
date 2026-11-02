class_name ForestPlanetSettings
extends Resource

## One Inspector-editable source for forest layout and storm timing. Enemy
## combat values remain editable on their own PackedScene roots.
## Every tree is a potential treant: the whole map is packed with them.
@export_range(40, 8000, 1) var maximum_trees: int = 6000
@export_range(30.0, 300.0, 1.0) var tree_spacing: float = 46.0
@export_range(0.0, 1000.0, 1.0) var empty_radius: float = 200.0
@export_range(0.0, 600.0, 1.0) var sparse_ring_width: float = 200.0
@export_range(0.0, 1.0, 0.01) var sparse_ring_density: float = 0.06
## Treant rings (user design): wave N raises part of ring N (plus regrown
## inner trees). ring_width = depth of one ring (0 = one tree row);
## ring_raise_fraction = share of that ring's trees that rise.
@export_range(0.0, 400.0, 1.0) var ring_width: float = 23.0
@export_range(0.05, 1.0, 0.01) var ring_raise_fraction: float = 0.4
@export_range(1, 99, 1) var final_canopy_wave: int = 12
## Keep the final-wave spectacle without instantiating every visible tree.
## Remaining standing trees stay as terrain; storm-regrown sites still return
## whenever a later wave selects them.
@export_range(0.05, 1.0, 0.01) var final_canopy_raise_fraction: float = 0.5
## All tree origins are selected together; instantiation is frame-capped.
@export_range(0.0, 10.0, 0.1) var ring_raise_duration: float = 0.0
@export_range(1, 128, 1) var maximum_ring_raises_per_frame: int = 64
@export_range(10.0, 600.0, 1.0) var storm_interval: float = 90.0
@export_range(0.0, 30.0, 0.5) var storm_warning_duration: float = 6.0
@export_range(1.0, 60.0, 0.5) var storm_duration: float = 12.0
## Spread one storm's unchanged quota across frames to avoid an instantiate spike.
@export_range(0.1, 3.0, 0.1) var respawn_spread_duration: float = 0.8
@export_range(1, 32, 1) var maximum_respawns_per_frame: int = 4
## Print frame/script/physics/draw-call and wave-spawn samples during profiling.
@export var log_performance: bool = false
