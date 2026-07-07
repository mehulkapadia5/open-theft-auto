extends Node
## Central rebindable-controls registry.
##
## Defines every rebindable action, wires it into Godot's InputMap (prefixed
## "g_" to stay clear of the built-in ui_* actions), persists overrides to
## user://controls.json, and renders clean display strings (keycap text /
## PlayStation glyph names) for the pause menu's controls screen.
##
## Actions are grouped for the controls screen UI: General / On Foot /
## Driving / Suit & Flight. Each entry's "key"/"mouse"/"pad" are its DEFAULT
## bindings (0 = no key/mouse default, -1 = no pad default) — the live
## bindings actually in effect live in the InputMap itself, which load()
## may have overridden from disk on startup.

signal changed

const SAVE_PATH := "user://controls.json"
const PREFIX := "g_"

const GROUP_ORDER := ["General", "On Foot", "Driving", "Suit & Flight"]

## name, label, group, default keyboard physical keycode, default mouse
## button index, default joypad button index.
const ACTIONS := [
	{"name": "interact", "label": "Interact", "group": "General",
		"key": KEY_E, "mouse": 0, "pad": JOY_BUTTON_X},
	{"name": "enter_exit", "label": "Enter / Exit Vehicle", "group": "General",
		"key": KEY_F, "mouse": 0, "pad": JOY_BUTTON_Y},
	{"name": "summon_suit", "label": "Summon Suit", "group": "General",
		"key": KEY_V, "mouse": 0, "pad": JOY_BUTTON_B},
	{"name": "phone", "label": "Phone", "group": "General",
		"key": KEY_P, "mouse": 0, "pad": JOY_BUTTON_BACK},
	{"name": "mute", "label": "Mute Sound", "group": "General",
		"key": KEY_M, "mouse": 0, "pad": -1},
	{"name": "restock_respawn", "label": "Restock HP + Ammo / Respawn", "group": "General",
		"key": KEY_R, "mouse": 0, "pad": JOY_BUTTON_DPAD_UP},
	{"name": "race_terminal", "label": "Grand Prix Terminal", "group": "General",
		"key": KEY_G, "mouse": 0, "pad": JOY_BUTTON_DPAD_DOWN},

	{"name": "move_forward", "label": "Move Forward", "group": "On Foot",
		"key": KEY_W, "mouse": 0, "pad": -1},
	{"name": "move_back", "label": "Move Back", "group": "On Foot",
		"key": KEY_S, "mouse": 0, "pad": -1},
	{"name": "move_left", "label": "Move Left", "group": "On Foot",
		"key": KEY_A, "mouse": 0, "pad": -1},
	{"name": "move_right", "label": "Move Right", "group": "On Foot",
		"key": KEY_D, "mouse": 0, "pad": -1},
	{"name": "sprint_boost", "label": "Sprint / Boost", "group": "On Foot",
		"key": KEY_SHIFT, "mouse": 0, "pad": -1},
	{"name": "aim", "label": "Aim / Zoom", "group": "On Foot",
		"key": KEY_SPACE, "mouse": 0, "pad": -1},
	{"name": "fire", "label": "Fire", "group": "On Foot",
		"key": 0, "mouse": MOUSE_BUTTON_LEFT, "pad": -1},
	{"name": "alt_fire", "label": "Alt Fire / Missiles", "group": "On Foot",
		"key": 0, "mouse": MOUSE_BUTTON_RIGHT, "pad": -1},
	{"name": "weapon_next", "label": "Next Weapon", "group": "On Foot",
		"key": KEY_Q, "mouse": 0, "pad": JOY_BUTTON_RIGHT_SHOULDER},
	{"name": "weapon_prev", "label": "Previous Weapon", "group": "On Foot",
		"key": KEY_Z, "mouse": 0, "pad": JOY_BUTTON_LEFT_SHOULDER},

	{"name": "handbrake", "label": "Handbrake", "group": "Driving",
		"key": KEY_SPACE, "mouse": 0, "pad": JOY_BUTTON_X},

	{"name": "fly_up", "label": "Fly / Climb Up", "group": "Suit & Flight",
		"key": KEY_UP, "mouse": 0, "pad": -1},
	{"name": "fly_down", "label": "Fly / Descend Down", "group": "Suit & Flight",
		"key": KEY_DOWN, "mouse": 0, "pad": -1},
]

## Extra keyboard fallback events kept alongside an action's primary default
## (lost the moment that action is rebound — a deliberate simplification so
## the rebind UI only ever has one keyboard slot to manage).
const LEGACY_KB_FALLBACK := {
	"weapon_next": [KEY_TAB],
}

## "interact" and "handbrake" share the Square/X button by design (mirrors the
## original hardcoded scheme — you're never both mid-kiosk and mid-drive) so
## the controller diagram shows one clickable callout for both; rebinding one
## keeps the other in sync.
const PAD_YOKED := {
	"interact": "handbrake",
	"handbrake": "interact",
}

var _by_name := {}
var _last_device := "kb"   # "kb" or "pad" — most recent input type seen


func _ready() -> void:
	for a in ACTIONS:
		_by_name[a.name] = a
		var id := action_id(a.name)
		if not InputMap.has_action(id):
			InputMap.add_action(id)
		InputMap.action_erase_events(id)
		_add_default_events(id, a)
	load_bindings()


func action_id(name: String) -> StringName:
	return StringName(PREFIX + name)


func label_for(name: String) -> String:
	return _by_name.get(name, {}).get("label", name)


func actions_in_group(group: String) -> Array:
	var out := []
	for a in ACTIONS:
		if a.group == group:
			out.append(a)
	return out


# =====================================================================
# Device tracking — drives which tab the controls screen auto-selects.
# =====================================================================
func note_event(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		_last_device = "kb"
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_last_device = "pad"


func preferred_device() -> String:
	if _last_device == "pad" and not Input.get_connected_joypads().is_empty():
		return "pad"
	return "kb"


# =====================================================================
# Display strings
# =====================================================================
func binding_text(name: String, device: String) -> String:
	var id := action_id(name)
	if not InputMap.has_action(id):
		return "—"
	for ev in InputMap.action_get_events(id):
		if device == "kb":
			if ev is InputEventKey:
				return _key_label(ev.physical_keycode)
			elif ev is InputEventMouseButton:
				return _mouse_label(ev.button_index)
		elif device == "pad" and ev is InputEventJoypadButton:
			return _pad_label(ev.button_index)
	return "—"


static func _key_label(kc: int) -> String:
	match kc:
		KEY_SPACE: return "SPACE"
		KEY_SHIFT: return "SHIFT"
		KEY_CTRL: return "CTRL"
		KEY_ALT: return "ALT"
		KEY_UP: return "↑"
		KEY_DOWN: return "↓"
		KEY_LEFT: return "←"
		KEY_RIGHT: return "→"
		KEY_TAB: return "TAB"
		KEY_ESCAPE: return "ESC"
		KEY_ENTER: return "ENTER"
		_:
			var s := OS.get_keycode_string(kc)
			return s.to_upper() if s != "" else "?"


static func _mouse_label(idx: int) -> String:
	match idx:
		MOUSE_BUTTON_LEFT: return "LMB"
		MOUSE_BUTTON_RIGHT: return "RMB"
		MOUSE_BUTTON_MIDDLE: return "MMB"
		MOUSE_BUTTON_WHEEL_UP: return "WHEEL UP"
		MOUSE_BUTTON_WHEEL_DOWN: return "WHEEL DOWN"
		_: return "MOUSE %d" % idx


static func _pad_label(idx: int) -> String:
	match idx:
		JOY_BUTTON_A: return "✕"
		JOY_BUTTON_B: return "○"
		JOY_BUTTON_X: return "□"
		JOY_BUTTON_Y: return "△"
		JOY_BUTTON_LEFT_SHOULDER: return "L1"
		JOY_BUTTON_RIGHT_SHOULDER: return "R1"
		JOY_BUTTON_LEFT_STICK: return "L3"
		JOY_BUTTON_RIGHT_STICK: return "R3"
		JOY_BUTTON_BACK: return "SHARE"
		JOY_BUTTON_START: return "OPTIONS"
		JOY_BUTTON_DPAD_UP: return "D-PAD ↑"
		JOY_BUTTON_DPAD_DOWN: return "D-PAD ↓"
		JOY_BUTTON_DPAD_LEFT: return "D-PAD ←"
		JOY_BUTTON_DPAD_RIGHT: return "D-PAD →"
		_: return "BTN %d" % idx


# =====================================================================
# Rebinding
# =====================================================================
## Rebind `name` on the given device ("kb" covers both keyboard keys and
## mouse buttons, "pad" covers joypad buttons) to `event`. Any other action
## already bound to the identical physical input on the same device is
## un-bound first, so a deliberate reassignment never leaves two actions
## silently sharing one button.
func rebind(name: String, device: String, event: InputEvent) -> void:
	if not _by_name.has(name):
		return
	# Yoked actions (interact/handbrake share Square by design) move together —
	# clear conflicts against every OTHER action ONCE, exempting the whole
	# yoked group, then apply the new event to each group member. Doing the
	# conflict pass per-member would have each member "steal" the input right
	# back off the other the moment it was set.
	var group := [name]
	if device == "pad" and PAD_YOKED.has(name):
		group.append(PAD_YOKED[name])
	_clear_conflicts(device, event, group)
	for n in group:
		var id := action_id(n)
		for ev in InputMap.action_get_events(id):
			if _event_device(ev) == device:
				InputMap.action_erase_event(id, ev)
		InputMap.action_add_event(id, event)
	save()
	changed.emit()


func reset_defaults() -> void:
	for a in ACTIONS:
		var id := action_id(a.name)
		InputMap.action_erase_events(id)
		_add_default_events(id, a)
	save()
	changed.emit()


func _add_default_events(id: StringName, a: Dictionary) -> void:
	if a.key != 0:
		var ek := InputEventKey.new()
		ek.physical_keycode = a.key
		InputMap.action_add_event(id, ek)
		for fallback in LEGACY_KB_FALLBACK.get(a.name, []):
			var ef := InputEventKey.new()
			ef.physical_keycode = fallback
			InputMap.action_add_event(id, ef)
	if a.mouse != 0:
		var em := InputEventMouseButton.new()
		em.button_index = a.mouse
		InputMap.action_add_event(id, em)
	if a.pad != -1:
		var ej := InputEventJoypadButton.new()
		ej.button_index = a.pad
		InputMap.action_add_event(id, ej)


func _event_device(ev: InputEvent) -> String:
	if ev is InputEventKey or ev is InputEventMouseButton:
		return "kb"
	if ev is InputEventJoypadButton:
		return "pad"
	return ""


func _clear_conflicts(device: String, event: InputEvent, exempt_names: Array) -> void:
	for a in ACTIONS:
		if a.name in exempt_names:
			continue
		var id := action_id(a.name)
		for ev in InputMap.action_get_events(id):
			if _event_device(ev) == device and _same_input(ev, event):
				InputMap.action_erase_event(id, ev)


static func _same_input(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return a.physical_keycode == b.physical_keycode
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return a.button_index == b.button_index
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return a.button_index == b.button_index
	return false


# =====================================================================
# Persistence
# =====================================================================
func save() -> void:
	var out := {}
	for a in ACTIONS:
		var id := action_id(a.name)
		var evs := []
		for ev in InputMap.action_get_events(id):
			if ev is InputEventKey:
				evs.append({"t": "key", "v": ev.physical_keycode})
			elif ev is InputEventMouseButton:
				evs.append({"t": "mouse", "v": ev.button_index})
			elif ev is InputEventJoypadButton:
				evs.append({"t": "pad", "v": ev.button_index})
		out[a.name] = evs
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(out))
	f.close()


func load_bindings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) != TYPE_DICTIONARY:
		return
	for a in ACTIONS:
		if not d.has(a.name):
			continue
		var evs = d[a.name]
		if typeof(evs) != TYPE_ARRAY:
			continue
		var id := action_id(a.name)
		InputMap.action_erase_events(id)
		for e in evs:
			if typeof(e) != TYPE_DICTIONARY:
				continue
			match str(e.get("t", "")):
				"key":
					var ek := InputEventKey.new()
					ek.physical_keycode = int(e.get("v", 0))
					InputMap.action_add_event(id, ek)
				"mouse":
					var em := InputEventMouseButton.new()
					em.button_index = int(e.get("v", 0))
					InputMap.action_add_event(id, em)
				"pad":
					var ej := InputEventJoypadButton.new()
					ej.button_index = int(e.get("v", 0))
					InputMap.action_add_event(id, ej)
	changed.emit()
