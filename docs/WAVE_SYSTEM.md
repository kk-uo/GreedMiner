# GreedMiner Wave System

The battle scene uses `WaveManager` with a planet-specific `PlanetWaveConfig` Resource. Rocky Planet data lives in `res://Resources/Waves/RockyPlanetWaves.tres`; runtime code contains no Rocky Planet enemy counts.

## Inspector workflow

1. In Godot's FileSystem dock, open `Resources/Waves/RockyPlanetWaves.tres`.
2. Expand `Waves`, then expand the desired array element.
3. Edit `Spawn Interval`, `Initial Spawn Delay`, `Maximum Simultaneous Enemies`, `Spawn Pattern`, or `Boss Wave`. Rocky Planet currently keeps `Preparation Duration` at `0`, so cleared waves transition immediately.
4. Expand that wave's `Enemy Entries`. Each entry exposes `Enemy Id`, `Enemy Scene`, `Spawn Count`, `Spawn First`, and `Is Boss`.
5. Save the Resource. The next battle reads the saved values automatically.

Each wave and enemy entry is a separate sub-resource, so changing one wave does not mutate another wave.

## Adding content

- To add a wave, increase the `Waves` array size, create a new `WaveDefinition` in the new slot, and add unique `EnemySpawnEntry` Resources to its `Enemy Entries` array.
- To replace an enemy, assign a different `PackedScene` that inherits `BasicEnemy` and update its stable `Enemy Id`.
- To configure another planet, create another `PlanetWaveConfig` `.tres`, populate its waves, and assign it to the battle scene's `WaveManager.wave_config` property. Future planet-specific battle scenes can each assign their own Resource.

## Public runtime interface

`WaveManager` exposes `start_wave_system()`, `stop_wave_system(reason)`, state/count getters, and signals for preparation, wave start, remaining enemies, boss health, completion, and cancellation. UI code should consume these signals and must not calculate wave progression itself.

`EnemySpawner` exposes `spawn_enemy(scene, pattern, sequence_index)` and `spawn_enemy_by_id(id, pattern, sequence_index)`. It only creates positioned enemies; `WaveManager` owns timing and quantities.

Rocky Planet uses continuous scheduling: after one wave's fixed enemy queue has been fully spawned, the next wave begins immediately. Enemies from earlier waves remain tracked and can overlap later waves. Planet completion still waits until Wave 9 has fully spawned and every living enemy and split descendant has died.
