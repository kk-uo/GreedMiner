class_name ResearchCostConfig
extends Resource

## Polynomial upgrade-cost configuration evaluated from the current level.
## Module upgrades (weapon damage, shield power) use base 200, linear 200,
## quadratic 0, i.e. Cost(L) = 200 x L where L is the current level.

@export_range(0, 1000000, 1) var base_upgrade_cost: int = 200
@export_range(0, 1000000, 1) var linear_cost_coefficient: int = 30
@export_range(0, 1000000, 1) var quadratic_cost_coefficient: int = 40


func get_upgrade_cost(current_level: int) -> int:
	var step := maxi(current_level - 1, 0)
	return (
		base_upgrade_cost
		+ linear_cost_coefficient * step
		+ quadratic_cost_coefficient * step * step
	)
