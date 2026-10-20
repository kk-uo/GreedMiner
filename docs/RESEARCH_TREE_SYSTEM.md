# Laboratory research trees

The Inspector resources are `Resources/Research/EnergyTree.tres`,
`Resources/Research/MiningTree.tres`, and `Resources/Research/ShipTree.tres`.
Each tree contains `ResearchTreeNode` resources. Their positions and
prerequisite IDs drive the view and connections; completion is stored only in
the existing ResearchManager progression section.

To add a node, expand `Nodes` in a tree resource, add a `ResearchTreeNode`,
and set its unique research ID, category, name, description, position and
prerequisite IDs. Assign a new `ResearchDefinition` to the node, or leave its
definition empty to refer to an existing ID in `ResearchConfiguration.tres`.
For a new definition set the matching ID/category, starting level 0, maximum
level 1, cost configuration, implemented flag and an appropriate effect.
Energy and Mining descendants can require `energy_install_slot_unlock` or
`mining_install_slot_unlock`; Ship branches can require `ship_max_hp_1`.
Existing effect types can be reused; a new gameplay effect requires its own
handler. No individual node scenes are needed.

ResearchManager checks graph validity and prerequisites on purchase, including
direct API calls. Completion and effect state use the normal research save.
Ship effects expose maximum HP bonus, regeneration amount/interval, and
artifact slot capacity through `ShipResearchEffect`. Existing artifact slots
that were occupied before the research requirement remain accessible until
emptied; the item and its ownership are not removed. New equipment requires an
unlocked slot. Magic Stall ownership remains independent of ship research.

UI can query `get_tree_node_state()`, `is_research_completed()` and
`get_upgrade_cost()` and listen to `research_level_changed`; gameplay should
query the effect resources rather than depend on the tree view.
