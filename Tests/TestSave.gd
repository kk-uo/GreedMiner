extends RefCounted

## Points ProgressionStore at a throwaway save for one test and reloads every
## manager from it, so a test never depends on (or overwrites) the player's
## real save, e.g. an equipped Stone Heart absorbing the damage a test checks.
## The isolated path stays active until the test process exits.
## Load with preload(); no class_name on purpose.

static func isolate(test_name: String) -> void:
	var temp_dir := OS.get_environment("TMPDIR")
	var test_path := temp_dir.path_join("greedminer_test_%s.json" % test_name) if not temp_dir.is_empty() else "user://test_%s.json" % test_name
	ProgressionStore.set_save_path_for_testing(test_path)
	ProgressionStore.reset_all_progress()
	WeaponUnlockManager.reload_progress()
	ShipLoadout.load_saved()
	ResourceManager.reload_persistent_resources()
	ResearchManager.reload_progress()
	ChipManager.reload_progress()
	ArtifactManager.reload_progress()
