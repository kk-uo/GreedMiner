class_name ModuleInstallationLimitResearchEffect
extends ResearchEffect

## One-time module-count permission. This effect changes installation
## validation only; it never changes module statistics or grants a module.

@export_range(0, 9, 1) var initial_installation_limit: int = 1
@export_range(0, 9, 1) var unlocked_installation_limit: int = 2
@export var purchase_button_text: String


func get_installation_limit(level: int) -> int:
	return (
		unlocked_installation_limit
		if level >= 1
		else initial_installation_limit
	)
