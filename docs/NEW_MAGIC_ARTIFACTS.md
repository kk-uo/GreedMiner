# New Mining-Chest Magic Artifacts

The three artifacts in this batch are registered in
`Resources/Artifacts/ArtifactConfiguration.tres`. Mining salvage chests read
that registry, so no separate drop table is required.

| Artifact | Rarity | Planet id | Runtime effect |
| --- | --- | --- | --- |
| Goblin Tooth | Rare | `goblin_planet` (Verdant) | Multiplies the equipped turret's final damage by `1.15`. |
| Bat Eyeball | Epic | `graveyard_planet` | Projectiles turn at up to 30 degrees/second, flame puffs turn at up to 120 degrees/second, and lasers may deflect by up to 8 degrees after passing their first target. Homing acquisition range is 600 px. |
| Dragon Wing | Rare | `dragon_nest_planet` | Lets a ground-only equipped turret acquire and damage flying enemies. |

Bat Eyeball's values are data parameters in `BatEyeball.tres`, so balance can
be changed without editing the steering code. Homing keeps the current target
until it becomes invalid or leaves range, then reacquires the nearest valid
target. A laser only bends when another valid target is inside its deflection
cone; otherwise it remains straight.

Bat Eyeball and Ghost Bullet are independent effects. A piercing projectile
keeps its Ghost Bullet penetration state, ignores targets it already hit, and
reacquires another target for homing.

The three artifacts use the existing module-compatibility inheritance for
fusion weapons. Goblin Tooth supports all five base weapons. Bat Eyeball and
Dragon Wing support the four turret bases (Machine Gun, Dwarf Cannon, Laser,
and Flamethrower), not the melee Chainsaw.
