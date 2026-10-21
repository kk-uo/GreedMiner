class_name ShipResearchEffect
extends ResearchEffect

## Ship-only research parameters. Gameplay reads these without mutating base HP.
@export_range(0.0, 100000.0, 0.1) var max_hp_bonus: float = 0.0
@export_range(0.0, 100000.0, 0.1) var regeneration_amount: float = 0.0
@export_range(0.01, 3600.0, 0.01) var regeneration_interval: float = 10.0
@export_range(0, 3, 1) var artifact_slots: int = 0
## Star-map destinations this research makes reachable (planet ids); those
## planets cannot be located or deployed to until it is researched.
@export var unlocked_planet_ids: Array[StringName] = []
## Extra power every Energy Module supplies (Energy Core research).
@export_range(0, 10, 1) var power_bonus: int = 0
## Extra ship power that needs no Energy Module (built into the hull).
@export_range(0, 10, 1) var base_power_bonus: int = 0
## Unlocks the Hangar's SHIP STYLE (colors and hull designs).
@export var unlocks_ship_style: bool = false
## Extra ship-grid expansion capacity every Energy Module supplies. This is
## only an interface for the future hull slot-expansion research: it raises
## Ship.total_expansion_capacity but does not add any slot by itself.
@export_range(0, 10, 1) var expansion_capacity_bonus: int = 0
## Extra max hull HP every installed Energy Module gives (Shielded Cells).
@export_range(0.0, 1000.0, 0.1) var energy_module_hp_bonus: float = 0.0
