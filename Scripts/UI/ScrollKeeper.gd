extends RefCounted

## Keeps scroll positions when a hangar panel rebuilds its rows (picking an
## item, buying, equipping...), so the list does not jump back to the top.
## Load with preload(); no class_name on purpose.
##
##   var saved := ScrollKeeper.capture(self)   # before clearing the rows
##   ... rebuild ...
##   ScrollKeeper.restore(self, saved)         # after adding the new rows
##
## Scroll containers are matched by their order in the tree under `root`, so
## only restore when the panel rebuilt the same view (pass [] otherwise).

## Frames to keep re-applying the position while the new rows lay out.
const SETTLE_FRAMES: int = 2


static func capture(root: Node) -> Array:
	var saved: Array = []
	if root == null:
		return saved
	for scroll in _scrolls(root):
		saved.append(Vector2i(scroll.scroll_horizontal, scroll.scroll_vertical))
	return saved


static func restore(root: Node, saved: Array) -> void:
	if root == null or saved.is_empty():
		return
	if not _apply(root, saved) or not root.is_inside_tree():
		return
	_settle(root, saved, SETTLE_FRAMES)


static func _settle(root: Node, saved: Array, frames: int) -> void:
	if frames <= 0 or not is_instance_valid(root) or not root.is_inside_tree():
		return
	root.get_tree().process_frame.connect(func() -> void:
		if is_instance_valid(root) and root.is_inside_tree():
			_apply(root, saved)
			_settle(root, saved, frames - 1)
	, CONNECT_ONE_SHOT)


## Returns true when some saved position is not at the top/left.
static func _apply(root: Node, saved: Array) -> bool:
	var any := false
	var scrolls := _scrolls(root)
	for index in range(mini(scrolls.size(), saved.size())):
		var value: Vector2i = saved[index]
		if value == Vector2i.ZERO:
			continue
		any = true
		scrolls[index].scroll_horizontal = value.x
		scrolls[index].scroll_vertical = value.y
	return any


static func _scrolls(root: Node) -> Array[ScrollContainer]:
	var found: Array[ScrollContainer] = []
	_collect(root, found)
	return found


static func _collect(node: Node, found: Array[ScrollContainer]) -> void:
	for child in node.get_children():
		# Rows already removed for a rebuild are queued for deletion; skip them.
		if child.is_queued_for_deletion():
			continue
		if child is ScrollContainer:
			found.append(child)
		_collect(child, found)
