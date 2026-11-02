# Rocky Planet high-risk mine

One deposit per Rocky Planet map (the farthest visible deposit from the ship)
becomes an optional high-risk mine. At least two ordinary deposits remain.

- The nine dormant stone markers are functional placeholders for final art.
- When a dwarf reaches the mine, it wakes one Rock Golem. Continuing after the
  first mining segment wakes three more; continuing after the second wakes five.
- The segments take the normal research-adjusted crystal mining time. They yield
  30, 80, and 160 ore before the existing crystal-value multiplier. The dwarf
  carries all completed segments until it returns to its module. Death drops
  unbanked ore, as with normal mining.
- A 1.5-second decision window follows each of the first two segments. Calling
  `DwarfMiner.recall()` before the next stage begins prevents its guards from
  waking. An interrupted mine keeps its stage progress for another dwarf visit.
- Woken Rock Golems use the ordinary enemy scene/AI and continue attacking the
  ship after the dwarf is recalled. These are event enemies, not wave quota.

`RiskyRockyCrystal.gd` owns stage state and emits `golems_awakened(positions)`;
`Battlefield.gd` relays it as `risky_mine_golems_awakened(positions)`; and
`BattleMain.gd` creates the Rock Golems. Final art can replace the stone markers
without changing this gameplay interface.
