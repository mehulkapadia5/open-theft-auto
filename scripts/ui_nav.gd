class_name UiNav
## Makes a menu controller-navigable: gives every button a visible focus ring
## and grabs focus on the first one, so the gamepad's built-in UI navigation
## (D-pad / left stick to move, Cross to select, Circle to cancel) has somewhere
## to start. Call `UiNav.apply.call_deferred(root)` from a terminal's open().

const HILITE := Color(0.96, 0.80, 0.36)   # warm gold focus ring


static func apply(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return
	var first: Button = null
	for b in _buttons(root):
		if b.focus_mode == Control.FOCUS_NONE:
			b.focus_mode = Control.FOCUS_ALL
		b.add_theme_stylebox_override("focus", _focus_box(b))
		# is_visible_in_tree, not visible: a button keeps its local flag even
		# when the whole view containing it is hidden.
		if first == null and b.is_visible_in_tree() and not b.disabled:
			first = b
	if first != null:
		first.grab_focus()


## Enable/disable keyboard-and-gamepad focus for every button under `root`.
## Used by terminals to fence off the background while a modal view is up —
## a dim ColorRect blocks the mouse, but focus navigation walks right past it.
static func set_focusable(root: Node, enabled: bool) -> void:
	if root == null or not is_instance_valid(root):
		return
	for b in _buttons(root):
		b.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE


static func _focus_box(b: Button) -> StyleBoxFlat:
	var base := b.get_theme_stylebox("normal")
	var sb: StyleBoxFlat
	if base is StyleBoxFlat:
		sb = (base as StyleBoxFlat).duplicate()
	else:
		sb = StyleBoxFlat.new()
	sb.set_border_width_all(3)
	sb.border_color = HILITE
	sb.set_corner_radius_all(maxi(sb.corner_radius_top_left, 3))
	return sb


static func _buttons(n: Node, acc: Array = []) -> Array:
	if n is Button:
		acc.append(n)
	for c in n.get_children():
		_buttons(c, acc)
	return acc
