extends Node3D
## Vice Beach 3D — main game orchestrator.
## Faithful Godot port of the Three.js prototype (game.js): procedural city,
## third-person player, cars + plane, 9 weapons, NPCs, police + wanted system.

# ---------------- Tuning constants (mirrors game.js) ----------------
# Realistic car colors — black, white, silver, gunmetal, maroon, navy, dark olive.
const VEHICLE_COLORS := [0x1b1b1d, 0xdcdcda, 0x9a9ca0, 0x4b4e54, 0x5e2a2a, 0x2b384e, 0x3a4438]
# Street traffic skews to ordinary cars, with the odd sports car mixed in.
const TRAFFIC_STYLES := ["sedan", "sedan", "sedan", "coupe", "coupe", "suv", "suv", "sports"]
const NPC_SKINS := [0xf4c28a, 0xd99770, 0xa87657, 0x7a5a40]
# Muted, earthy NPC clothing.
const NPC_SHIRTS := [0x8a4f3e, 0x47586a, 0x586a4a, 0x9c8a64, 0x3f4a58, 0x6f6f6c, 0xb0a690, 0x5a4c46]
const NPC_PANTS := [0x2a2e36, 0x33384a, 0x4a2a1a, 0x35435a, 0x4a4a44]
const NPC_HAIR := [0x2a1a08, 0x4a2a1a, 0xaa8866, 0x222222, 0xccaa44, 0xddccaa]
# President motorcade pacing.
const CONVOY_SPEED := 17.0       # how fast the motorcade rolls along its route
const CONVOY_SPACING := 9.0      # gap between convoy vehicles along the route

# ---------------- Nodes ----------------
var world: CityWorld
var camera: Camera3D
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var hud: HUD
var stock_terminal: StockTerminal
var dealership_terminal: DealershipTerminal
var suit_terminal: SuitTerminal
var realtor_terminal: RealtorTerminal
var race_terminal: RaceTerminal
var phone                        # the phone menu (loaded by path, see _ready)
var phone_open := false          # true while the phone menu is on screen
var terminal_open := false       # true while any kiosk terminal is on screen
var _near_exchange := false      # on foot and within reach of the exchange kiosk
var _near_dealership := false    # on foot and within reach of the dealership kiosk
var _near_stark := false         # on foot and within reach of the Stark lab kiosk
var _near_realtor := false       # on foot and within reach of the realtor kiosk
var _near_paddock := false       # in an F1 car at the Grand Prix paddock
var in_trading_floor := false    # inside the exchange's glass trading office
var _trading_return := Vector3.ZERO   # street position to drop back to on exit
var _near_trade_desk := false    # within reach of the office monitor desk
var _near_office_exit := false   # standing on the office exit pad
var _race_active := false        # the player is currently in a structured race
var _race_count_shown := -1      # last countdown number announced
var _owned_spawn = null          # the player's last car spawned onto the lot
var player_node: Node3D
var weapon_holder: Node3D       # holds the visible weapon prop in the player's hand

# ---------------- Player state ----------------
var player_pos := Vector3.ZERO
var player_yaw := 0.0
var player_hp := 100.0
var player_max_hp := 100.0
var player_armor := 0.0
var player_max_armor := 100.0

# ---------------- Camera ----------------
var cam_yaw := 0.0
var cam_pitch := 0.3
var cam_dist := 6.5
var aiming := false          # on foot, holding Space: first-person zoomed aim
const CAM_FOV_HIP := 70.0
const CAM_FOV_AIM := 32.0

# ---------------- Entity pools ----------------
var vehicles: Array = []
var npcs: Array = []
var cops: Array = []
var vips: Array = []        # rich civilians — big cash payout when killed
var guards: Array = []      # bodyguards escorting the VIPs
var bullets: Array = []
var particles: Array = []
var pickups: Array = []
var in_car = null
var parachuting := false
var para_node: Node3D = null

# ---------------- Iron Man suit ----------------
var suit_node: Node3D = null
var suit_state := "none"        # none / suiting / on
var suit_timer := 0.0
var suit_full_time := 2.5
var suit_vy := 0.0
var suit_armed := false
var repulsor_at := -10.0
var missile_at := -10.0
const SUIT_STAGGER := 0.1
const SUIT_GROW := 0.5
# Summon: plates detach from the parked suit and streak across the map onto the
# body, one staggered after the next, feet-first.
const SUIT_SUMMON_STAGGER := 0.05
const SUIT_SUMMON_FLIGHT := 0.8
# Repulsor/missile reach is fixed; damage scales with the suit tier (see
# SuitCatalog / Garage.suit_stats()).
const REPULSOR_RANGE := 95.0
const MISSILE_RANGE := 165.0

# ---------------- Loop bookkeeping ----------------
var walk_phase := 0.0
var _now := 0.0
var last_fire_at := -10.0
var cop_timer := 0.0
var wanted_decay := 0.0
var vip_spawn_timer := 0.0       # countdown to topping the streets back up with VIPs
var swat_timer := 0.0            # countdown to the next SWAT van at high wanted
var police_heli = null           # the hunting police chopper (4+ stars)
var _swat_vans: Array = []       # deployed SWAT van nodes
var car_drifting := false        # player car mid-handbrake-slide (race scoring)
var racers: Array = []           # AI race cars looping the F1 circuit
# Space programme — the rocket journey to the Moon and back.
var space_state := ""            # "" / ascent / space_climb / space / moon_descent
								 # / moon_landed / moon / moon_ascent / reentry / splashdown
var _falling_boosters: Array = []   # separated booster stages tumbling down
const ROCKET_BOOSTER_H := 15.0   # height of the booster stage
const ROCKET_BASE_Y := 0.85      # launch-pad top
# President & motorcade
var pres_state := "home"         # home / toairport / atairport / tohome / athome
var pres_timer := 75.0           # countdown to the next motorcade run
var president = null             # the President entity dict (also in `vips`)
var pres_aggro := false          # the detail has been provoked
var convoy_prog := 0.0           # distance the motorcade has covered along its route
var convoy_route: PackedVector3Array = PackedVector3Array()
var _convoy_route_len := 0.0
var city_owned := false          # the President is dead — the city is the player's
var _city_income := 0.0          # fractional accumulator for passive city revenue
var my_guards: Array = []        # the player-President's personal bodyguards
var my_convoy: Array = []        # the player-President's escort vehicles
var _convoy_form := 0.0          # seconds settled in a car — the convoy forms up
var race_rank := 1               # player's current circuit position
var race_total := 1
var _player_prog := 0.0          # player's monotonic race progress (centreline steps)
var _mouse_rel := Vector2.ZERO
const VIP_TARGET := 4            # VIPs are unlimited — kept topped up to this many

# ---------------- Shared materials ----------------
var head_mat: StandardMaterial3D
var tail_mat: StandardMaterial3D
var _bullet_mat: StandardMaterial3D
var _pickup_mat: StandardMaterial3D
var _repulsor_mat: StandardMaterial3D
var _missile_mat: StandardMaterial3D


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	_setup_environment()
	head_mat = Build.emissive(Build.hex(0xfff6c0), Build.hex(0xfff6c0), 0.06)
	tail_mat = Build.emissive(Build.hex(0xff3030), Build.hex(0xff2020), 0.08)
	_bullet_mat = Build.mat(Build.hex(0xfff7a8))
	_bullet_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pickup_mat = Build.emissive(Build.hex(0x8fb866), Build.hex(0x8fb866), 0.6)
	_repulsor_mat = Build.emissive(Build.hex(0x8fe6ff), Build.hex(0x8fe6ff), 5.0)
	_repulsor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_missile_mat = Build.emissive(Build.hex(0xffae3a), Build.hex(0xff7a20), 3.0)
	_missile_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	world = CityWorld.new()
	add_child(world)
	world.generate()

	player_node = Human.build(0xf4c28a, 0x2e2f33, 0x33384a, 0x2a1a08)
	add_child(player_node)
	var limbs: Dictionary = player_node.get_meta("limbs")
	weapon_holder = Node3D.new()
	weapon_holder.position = Vector3(0.0, -0.86, 0.18)
	limbs.armR.add_child(weapon_holder)
	_refresh_weapon_model()

	camera = Camera3D.new()
	camera.fov = 70.0
	camera.position = Vector3(0, 8, 12)
	camera.current = true
	add_child(camera)

	hud = HUD.new()
	add_child(hud)
	hud.start_pressed.connect(_on_start)
	hud.respawn_pressed.connect(_respawn)

	stock_terminal = StockTerminal.new()
	add_child(stock_terminal)
	stock_terminal.closed.connect(_on_terminal_closed)

	phone = load("res://scripts/phone.gd").new()
	add_child(phone)
	phone.closed.connect(_on_phone_closed)
	phone.action.connect(_on_phone_action)

	dealership_terminal = DealershipTerminal.new()
	add_child(dealership_terminal)
	dealership_terminal.closed.connect(_on_terminal_closed)
	dealership_terminal.spawn_requested.connect(_spawn_owned_vehicle)

	suit_terminal = SuitTerminal.new()
	add_child(suit_terminal)
	suit_terminal.closed.connect(_on_terminal_closed)
	suit_terminal.purchased.connect(_on_suit_purchased)

	realtor_terminal = RealtorTerminal.new()
	add_child(realtor_terminal)
	realtor_terminal.closed.connect(_on_terminal_closed)

	race_terminal = RaceTerminal.new()
	add_child(race_terminal)
	race_terminal.closed.connect(_on_terminal_closed)
	race_terminal.start_requested.connect(_start_race)
	RaceManager.race_finished.connect(_on_race_finished)

	GameState.started = false
	GameState.paused = false
	GameState.init_weapon_ammo()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _setup_environment() -> void:
	var we := WorldEnvironment.new()
	add_child(we)
	env = Environment.new()
	we.environment = env
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 8.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_density = 0.0007
	env.fog_sky_affect = 0.2

	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.light_energy = 1.0
	sun.rotation = Vector3(deg_to_rad(-55.0), 0.7, 0.0)
	add_child(sun)


# =====================================================================
# Game flow
# =====================================================================
func _on_start() -> void:
	GameState.started = true
	GameState.paused = false
	GameState.reset_run()
	StockMarket.reset()
	RaceManager.reset()
	RaceManager.track = world.track
	Garage.reset()
	terminal_open = false
	_near_exchange = false
	_near_dealership = false
	_near_stark = false
	_near_realtor = false
	_near_paddock = false
	_race_active = false
	_race_count_shown = -1
	_player_prog = 0.0
	_owned_spawn = null
	var s := world.find_safe_spawn()
	player_pos = Vector3(s.x, 0, s.y)
	player_node.position = player_pos
	player_node.visible = true
	_spawn_vehicles(40)
	_spawn_airport_aircraft()
	_spawn_boats()
	for i in 40:
		_spawn_npc()
	_spawn_vip_groups(VIP_TARGET)
	_spawn_iron_suit()
	_spawn_racers()
	_spawn_rocket()
	_spawn_moon_buggy()
	space_state = ""
	AudioFX.start_ambient()
	# President motorcade — armed and on a timer.
	pres_state = "home"
	pres_timer = 75.0
	president = null
	pres_aggro = false
	convoy_prog = 0.0
	city_owned = false
	_city_income = 0.0
	player_max_armor = 100.0
	player_armor = 0.0
	player_hp = player_max_hp
	for g in my_guards:
		if is_instance_valid(g.node):
			g.node.queue_free()
	my_guards.clear()
	for e in my_convoy:
		if is_instance_valid(e.node):
			e.node.queue_free()
	my_convoy.clear()
	_convoy_form = 0.0
	_build_convoy_route()
	hud.enter_game()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_show_objective("Rich VIPs roam the city - rob them for cash. An IRON MAN SUIT stands nearby - press V to call it to you from anywhere, or step onto it, to fly. Downtown is the place to spend: STOCK EXCHANGE, VICE AUTOS (cars), STARK INDUSTRIES (suit upgrades) and VICE REALTY (safehouses) - press E at each kiosk.", 11.0)


func _die() -> void:
	GameState.paused = true
	GameState.money = max(0, GameState.money - (10 + randi() % 6))
	hud.show_death()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _respawn() -> void:
	hud.hide_death()
	GameState.paused = false
	GameState.wanted = 0.0
	# Drop out of any space leg cleanly — sky and gravity back to normal.
	if space_state != "":
		space_state = ""
		_set_space_sky(false)
	for c in cops:
		c.node.queue_free()
	cops.clear()
	# Bodyguards stand down once you respawn — guards of a dead VIP disband,
	# guards still protecting a live VIP go back to escorting calmly.
	var kept_guards: Array = []
	for g in guards:
		if g.vip == null:
			g.node.queue_free()
		else:
			g.aggro = false
			g.hp = g.max_hp
			kept_guards.append(g)
	guards = kept_guards
	for v in vips:
		v.aggro = false
		v.hp = v.max_hp
	parachuting = false
	if para_node != null:
		para_node.queue_free()
		para_node = null
	# Respawn at the player's safehouse if they own one, else a safe city spot.
	var s: Vector2
	if Garage.active_property >= 0:
		var home: Dictionary = PropertyCatalog.LIST[Garage.active_property]
		s = Vector2(home.x, home.z)
	else:
		s = world.find_safe_spawn()
	player_pos = Vector3(s.x, 0, s.y)
	player_hp = player_max_hp
	player_armor = 0.0
	in_car = null
	_near_exchange = false
	_near_dealership = false
	_near_stark = false
	_near_realtor = false
	_near_paddock = false
	if in_trading_floor:
		in_trading_floor = false
		world.set_trading_floor(false)
		_near_trade_desk = false
		_near_office_exit = false
	if _race_active:
		RaceManager.abort_race()
		_race_active = false
	player_node.visible = true
	GameState.init_weapon_ammo()
	if Garage.active_property >= 0:
		_show_objective("Home at %s. Try not to die." %
			PropertyCatalog.LIST[Garage.active_property].name)
	else:
		_show_objective("You're back. Try not to die.")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# =====================================================================
# Input
# =====================================================================
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_mouse_rel += event.relative
		return
	if not GameState.started or GameState.paused:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and in_car == null:
			_switch_weapon(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and in_car == null:
			_switch_weapon(-1)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event.keycode)
		# Consume the key so it can't also reach the trading terminal's own
		# close handler on the same frame it was opened.
		get_viewport().set_input_as_handled()


func _handle_key(keycode: int) -> void:
	match keycode:
		KEY_F:
			if suit_state == "on":
				_unsuit()
			elif suit_state == "none" and not in_trading_floor:
				_try_enter_exit()
		KEY_V:
			if suit_state == "none" and in_car == null and not parachuting \
				and not terminal_open and not in_trading_floor:
				_summon_suit()
		KEY_E:
			if terminal_open or in_car != null \
				or suit_state != "none" or parachuting:
				return
			if in_trading_floor:
				if _near_trade_desk:
					_open_terminal()
				elif _near_office_exit:
					_exit_trading_floor()
			elif _near_exchange:
				_enter_trading_floor()
			elif _near_dealership:
				_open_dealership()
			elif _near_stark:
				_open_stark()
			elif _near_realtor:
				_open_realtor()
		KEY_G:
			if not terminal_open and _near_paddock and not RaceManager.is_active():
				_open_race_terminal()
		KEY_P:
			if not terminal_open and not phone_open:
				_open_phone()
		KEY_Q, KEY_TAB:
			_switch_weapon(1)
		KEY_Z:
			_switch_weapon(-1)
		KEY_R:
			if player_hp > 0:
				player_hp = player_max_hp
				GameState.init_weapon_ammo()
				_show_objective("Full HP + ammo restocked")
			else:
				_respawn()
		KEY_M:
			AudioFX.set_muted(not AudioFX.is_muted())
			_show_objective("Muted" if AudioFX.is_muted() else "Sound on")
		KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_:
			if keycode >= KEY_1 and keycode <= KEY_9:
				_select_weapon(keycode - KEY_1)


func _key(k: int) -> bool:
	return Input.is_physical_key_pressed(k)


# ---------------- Kiosk terminals ----------------
func _open_terminal() -> void:
	terminal_open = true
	GameState.paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	stock_terminal.open()


func _open_dealership() -> void:
	terminal_open = true
	GameState.paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	dealership_terminal.open()


func _open_stark() -> void:
	terminal_open = true
	GameState.paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	suit_terminal.open()


func _open_realtor() -> void:
	terminal_open = true
	GameState.paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	realtor_terminal.open()


# ---------------- Trading-floor office ----------------
func _enter_trading_floor() -> void:
	_trading_return = player_pos
	in_trading_floor = true
	world.set_trading_floor(true)
	var ex: Dictionary = CityWorld.OFFICE_EXIT
	player_pos = Vector3(ex.x, CityWorld.TRADING_FLOOR.y, ex.z)
	player_yaw = 0.0
	player_node.position = player_pos
	player_node.rotation.y = player_yaw
	_near_exchange = false
	AudioFX.coin()
	_show_objective("Exchange trading floor — walk to the desk to trade.", 4.5)


func _exit_trading_floor() -> void:
	in_trading_floor = false
	world.set_trading_floor(false)
	_near_trade_desk = false
	_near_office_exit = false
	player_pos = _trading_return
	player_pos.y = world.surface_height(player_pos.x, player_pos.z)
	player_node.position = player_pos
	_show_objective("Back on the street.", 2.5)


func _open_race_terminal() -> void:
	terminal_open = true
	GameState.paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	race_terminal.open()


## Begin a Grand Prix: charge the entry fee + bet, put the player on pole and
## the AI on the grid, and roll the countdown.
func _start_race(laps: int, bet: int) -> void:
	var t: Track = world.track
	if t == null or in_car == null:
		return
	var cost: int = RaceManager.ENTRY_FEE + bet
	if GameState.money < cost:
		return
	GameState.money -= cost
	RaceManager.start_race(laps, bet)
	_race_active = true
	_race_count_shown = -1
	# Player starts on pole.
	var pole: Vector3 = t.grid_slot(0)
	in_car.pos = Vector3(pole.x, 0.0, pole.z)
	in_car.speed = 0.0
	in_car.yaw = t.grid_yaw()
	in_car.node.position = in_car.pos
	in_car.node.rotation.y = in_car.yaw
	player_pos = in_car.pos
	# Line the AI field up just behind the start line, on the grid behind pole.
	_player_prog = 0.0
	var n: int = t.baked.size()
	for i in racers.size():
		var r = racers[i]
		r.fi = float(n) - 3.0 - i * 2.0
		r.lap = 0
		r.speed = 0.0
		r.prog = -4.0 - i * 2.0
	_show_objective("Grand Prix — %d laps. Get ready..." % laps, 3.0)


## Settle a finished race: place the player and pay out the bet.
func _on_race_finished() -> void:
	if not _race_active:
		return
	_race_active = false
	var place: int = race_rank
	var won: int = RaceManager.settle(place)
	if place == 1:
		_show_objective("WON THE GRAND PRIX!  P1  —  payout $%d" % won, 9.0)
	elif won > 0:
		_show_objective("Finished P%d of %d  —  payout $%d" % [place, race_total, won], 9.0)
	else:
		_show_objective("Finished P%d of %d  —  bet lost." % [place, race_total], 9.0)


## After buying a suit tier at Stark, deliver the suit to the lit pad beside
## the kiosk so the player can walk over and step onto it. If a suit is already
## being worn, the upgrade just applies live.
func _on_suit_purchased() -> void:
	var nm: String = Garage.suit_stats().name
	if suit_state == "none" and suit_node != null:
		_refresh_suit_model()            # show the bought tier's livery
		suit_node.position = Vector3(CityWorld.STARK_SUIT_PAD.x, 0.0,
			CityWorld.STARK_SUIT_PAD.z)
		suit_armed = true
		_show_objective("%s delivered to the SUIT BAY pad outside — press V to call it to you, or step onto it, to suit up." % nm, 7.0)
	else:
		_show_objective("Suit upgraded to %s — its new look applies next time you suit up." % nm, 4.0)


## Drop the player's owned car `catalog_idx` onto the dealership lot. The
## previous lot car (if still parked and not being driven) is cleared first so
## owned spawns never pile up.
func _spawn_owned_vehicle(catalog_idx: int) -> void:
	var car: Dictionary = VehicleCatalog.LIST[catalog_idx]
	if _owned_spawn != null and _owned_spawn != in_car and _owned_spawn in vehicles:
		_owned_spawn.node.queue_free()
		vehicles.erase(_owned_spawn)
	_owned_spawn = null
	var sx: float = CityWorld.DEALERSHIP.x
	var sz: float = CityWorld.DEALERSHIP.z - 5.0
	var v := _make_vehicle(sx, sz, car.color, car.style)
	v.max_speed = car.max_speed
	v.yaw = 0.0
	v.node.rotation.y = v.yaw
	v["owned_spawn"] = true
	vehicles.append(v)
	_owned_spawn = v
	_show_objective("Your %s is on the lot — walk over and press F to drive." % car.name, 5.0)


func _on_terminal_closed() -> void:
	terminal_open = false
	GameState.paused = false
	_mouse_rel = Vector2.ZERO          # drop look-input built up while trading
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ---------------- Phone ----------------
func _open_phone() -> void:
	phone_open = true
	GameState.paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	phone.open()


func _on_phone_closed() -> void:
	phone_open = false
	GameState.paused = false
	_mouse_rel = Vector2.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Carry out a phone quick-action — vehicle delivery, fast travel or a service.
func _on_phone_action(id: String) -> void:
	match id:
		"car_sports":
			_phone_deliver_car("sports", 54.0, 0x2b384e)
		"car_f1":
			_phone_deliver_car("f1", 100.0, 0xc0392b)
		"tp_airport":
			_phone_teleport(CityWorld.AIRPORT.x, CityWorld.AIRPORT.z)
		"tp_exchange":
			_phone_teleport(CityWorld.EXCHANGE.x, CityWorld.EXCHANGE.z)
		"tp_launch":
			_phone_teleport(CityWorld.LAUNCH.x, CityWorld.LAUNCH.z)
		"heal":
			player_hp = player_max_hp
			player_armor = player_max_armor
			GameState.init_weapon_ammo()
			_show_objective("Full heal and ammo restock.", 4.0)
		"bribe":
			if GameState.money >= 50000:
				GameState.money -= 50000
				GameState.wanted = 0.0
				for c in cops:
					c.node.queue_free()
				cops.clear()
				_clear_police_extras()
				_show_objective("Cops bribed — you're off the radar.", 4.0)
			else:
				_show_objective("Not enough cash to bribe the cops.", 4.0)


func _phone_deliver_car(style: String, speed: float, color: int) -> void:
	var c := _make_vehicle(player_pos.x + 5.0, player_pos.z + 2.0, color, style)
	c.max_speed = speed
	vehicles.append(c)
	_show_objective("A %s was delivered beside you." % style, 4.0)


func _phone_teleport(x: float, z: float) -> void:
	in_car = null
	parachuting = false
	cam_dist = 6.5
	if space_state != "":
		space_state = ""
		_set_space_sky(false)
	player_pos = Vector3(x, 0, z)
	player_node.position = player_pos
	player_node.visible = true
	_show_objective("Fast-travelled.", 3.0)


# =====================================================================
# Main loop
# =====================================================================
func _process(delta: float) -> void:
	if not GameState.started or GameState.paused:
		return
	var dt: float = min(0.05, delta)
	_now += dt
	GameState.time_min = fmod(GameState.time_min + dt * 0.5, 1440.0)
	walk_phase += dt * 8.0

	var rel := _mouse_rel
	_mouse_rel = Vector2.ZERO
	# In any vehicle the chase cam is automatic — the mouse only steers it on foot.
	if in_car == null:
		# Slower, finer mouse while zoomed in to aim.
		var sens := 0.0011 if aiming else 0.0025
		cam_yaw -= rel.x * sens
		cam_pitch -= rel.y * sens
		cam_pitch = clamp(cam_pitch, -0.2, 1.2)

	if parachuting:
		_update_parachute(dt)
	elif in_car != null:
		if in_car.get("is_rocket", false):
			_update_rocket(in_car, dt)
		elif in_car.get("moon", false):
			_update_moon_buggy(in_car, dt)
		elif in_car.get("is_heli", false):
			_update_helicopter(in_car, dt)
		elif in_car.get("is_boat", false):
			_update_boat(in_car, dt)
		elif in_car.is_plane:
			_update_plane(in_car, dt)
		else:
			_update_car(in_car, dt)
	elif suit_state == "suiting":
		_update_suiting(dt)
	elif suit_state == "summoning":
		_update_summoning(dt)
	elif suit_state == "on":
		_update_suit(dt)
	else:
		_update_on_foot(dt)

	# Chase cam: in a car or plane the camera auto-swings behind the vehicle's
	# heading — turn left and the view follows left, turn right and it follows
	# right — a third-person driver's view with no mouse needed.
	if in_car != null:
		var follow: float = min(1.0, dt * 6.0)
		cam_yaw = lerp_angle(cam_yaw, in_car.yaw + PI, follow)
		var target_pitch: float = 0.2 if in_car.is_plane else 0.32
		cam_pitch = lerp(cam_pitch, target_pitch, follow)

	# Hold Space to aim down the crosshair in zoomed first-person (on foot or
	# suited — only the mid-assembly suit-up locks it out).
	aiming = in_car == null and not parachuting and suit_state != "suiting" \
		and suit_state != "summoning" and _key(KEY_SPACE)

	# Idle bob/spin for the parked Iron Man suit waiting to be worn.
	if suit_node != null and suit_state == "none":
		suit_node.rotation.y += dt * 0.7
		suit_node.position.y = _ground_y() + 0.06 + sin(_now * 2.0) * 0.12

	_update_shooting()
	_update_tank_fire()
	_update_npcs(dt)
	_update_cops(dt)
	_update_police_heli(dt)
	_update_vips(dt)
	_update_guards(dt)
	_update_president(dt)
	_update_my_detail(dt)
	_update_wanted(dt)
	_update_bullets(dt)
	_update_particles(dt)
	_update_pickups(dt)

	# Once the city is owned, the treasury pays out a steady passive income and
	# the President's armour stays maxed — 1000x a normal vest.
	if city_owned:
		_city_income += dt * 200000.0
		if _city_income >= 1.0:
			var inc := int(_city_income)
			GameState.money += inc
			_city_income -= inc
		player_armor = player_max_armor

	if GameState.wanted == 0.0 and player_hp < player_max_hp:
		player_hp = min(player_max_hp, player_hp + dt * 4.0)
	if player_hp <= 0.0:
		_die()
		return

	if not _in_space_sky():
		_update_daynight()
	_update_falling_boosters(dt)
	for c in world.clouds:
		c.node.position.x += c.drift * dt
		if c.node.position.x > CityWorld.WORLD:
			c.node.position.x = -CityWorld.WORLD
	_update_racers(dt)
	RaceManager.tick(dt, player_pos,
		in_car != null and not in_car.is_plane, car_drifting)
	_update_race(dt)
	AudioFX.set_radio(in_car != null and not in_car.is_plane
		and not in_car.get("is_boat", false))
	_update_camera()
	_push_hud()


# ---------------- Grand Prix race ----------------
## Per-frame race housekeeping: paddock proximity, countdown announcements and
## forfeit detection.
func _update_race(dt: float) -> void:
	# Paddock proximity — only in an F1 car, between races.
	var np := false
	if in_car != null and in_car.get("style", "") == "f1" and world.track != null \
		and not RaceManager.is_active():
		var pp: Vector3 = world.track.paddock_pos
		np = Vector2(pp.x - in_car.pos.x, pp.z - in_car.pos.z).length() < 9.0
	if np and not _near_paddock:
		_show_objective("Grand Prix paddock — press G to enter a race.", 4.0)
	_near_paddock = np

	# Countdown announcements.
	if RaceManager.state == "countdown":
		var c := int(ceil(RaceManager.countdown))
		if c != _race_count_shown:
			_race_count_shown = c
			if c >= 1 and c <= 3:
				_show_objective(str(c), 1.0)
	elif RaceManager.state == "racing" and _race_count_shown != 0:
		_race_count_shown = 0
		_show_objective("GO!", 1.5)

	# Forfeit the race if the player loses the car.
	if _race_active and (in_car == null or not vehicles.has(in_car)):
		RaceManager.abort_race()
		_race_active = false
		_show_objective("Race forfeited — bet and entry fee lost.", 5.0)


# ---------------- On foot ----------------
## Floaty low-gravity walk on the Moon — slower, with a bounding bob, no city
## collision (the lunar surface is open).
func _update_moon_walk(dt: float) -> void:
	var mx := (1.0 if _key(KEY_D) else 0.0) - (1.0 if _key(KEY_A) else 0.0)
	var mz := (1.0 if _key(KEY_W) else 0.0) - (1.0 if _key(KEY_S) else 0.0)
	var l := sqrt(mx * mx + mz * mz)
	var spd := 4.6 if _key(KEY_SHIFT) else 2.9
	if l > 0.0:
		mx /= l
		mz /= l
		var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
		var rgt := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
		var dx := (rgt.x * mx + fwd.x * mz) * spd * dt
		var dz := (rgt.z * mx + fwd.z * mz) * spd * dt
		player_pos.x += dx
		player_pos.z += dz
		player_yaw = atan2(dx, dz)
	var bob: float = absf(sin(walk_phase * 0.45)) * (0.55 if l > 0.0 else 0.0)
	player_pos.y = CityWorld.MOON_Y + bob
	player_node.position = player_pos
	player_node.rotation.y = player_yaw
	Human.animate(player_node, walk_phase * 0.6, l > 0.0, 0.7, 0.49)

	# Step back onto the parked suit to re-wear it (and re-arm V summon).
	if suit_node != null and suit_state == "none":
		var sd := Vector2(suit_node.position.x - player_pos.x,
			suit_node.position.z - player_pos.z).length()
		if not suit_armed and sd > 3.6:
			suit_armed = true
		if suit_armed and sd < 2.2:
			_begin_suit()


func _update_on_foot(dt: float) -> void:
	if space_state == "moon":
		_update_moon_walk(dt)
		return
	var mx := (1.0 if _key(KEY_D) else 0.0) - (1.0 if _key(KEY_A) else 0.0)
	var mz := (1.0 if _key(KEY_W) else 0.0) - (1.0 if _key(KEY_S) else 0.0)
	var l := sqrt(mx * mx + mz * mz)
	var spd := 8.0 if _key(KEY_SHIFT) else 4.5
	if l > 0.0:
		mx /= l
		mz /= l
		var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
		var rgt := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
		var dx := (rgt.x * mx + fwd.x * mz) * spd * dt
		var dz := (rgt.z * mx + fwd.z * mz) * spd * dt
		if not world.collides_at(player_pos.x + dx, player_pos.z, 0.4, player_pos.y):
			player_pos.x += dx
		if not world.collides_at(player_pos.x, player_pos.z + dz, 0.4, player_pos.y):
			player_pos.z += dz
		player_yaw = atan2(dx, dz)
	# Walk up onto raised surfaces — the river bridges and the dock jetties.
	player_pos.y = world.surface_height(player_pos.x, player_pos.z)
	player_node.position = player_pos
	player_node.rotation.y = player_yaw
	Human.animate(player_node, walk_phase, l > 0.0, 0.7, 0.49)

	# Step onto the parked Iron Man suit to put it on.
	if suit_node != null and suit_state == "none":
		var sd := Vector2(suit_node.position.x - player_pos.x,
			suit_node.position.z - player_pos.z).length()
		if not suit_armed and sd > 3.6:
			suit_armed = true
		if suit_armed and sd < 2.2:
			_begin_suit()

	# Walk up to the exchange kiosk to unlock the trading terminal (press E).
	var ed := Vector2(CityWorld.EXCHANGE.x - player_pos.x,
		CityWorld.EXCHANGE.z - player_pos.z).length()
	var near_exchange := ed < 3.6
	if near_exchange and not _near_exchange:
		_show_objective("Vice Beach Exchange - press E to enter the trading floor.", 4.0)
	_near_exchange = near_exchange

	# Walk up to the dealership kiosk to buy and spawn cars (press E).
	var dd := Vector2(CityWorld.DEALERSHIP.x - player_pos.x,
		CityWorld.DEALERSHIP.z - player_pos.z).length()
	var near_dealership := dd < 3.6
	if near_dealership and not _near_dealership:
		_show_objective("Vice Autos - press E to buy a car.", 4.0)
	_near_dealership = near_dealership

	# Walk up to the Stark lab kiosk to buy Iron Man suit upgrades (press E).
	var kd := Vector2(CityWorld.STARK_LAB.x - player_pos.x,
		CityWorld.STARK_LAB.z - player_pos.z).length()
	var near_stark := kd < 3.6
	if near_stark and not _near_stark:
		_show_objective("Stark Industries - press E to upgrade your suit.", 4.0)
	_near_stark = near_stark

	# Walk up to the realtor kiosk to buy safehouse property (press E).
	var rd := Vector2(CityWorld.REALTOR.x - player_pos.x,
		CityWorld.REALTOR.z - player_pos.z).length()
	var near_realtor := rd < 3.6
	if near_realtor and not _near_realtor:
		_show_objective("Vice Realty - press E to buy a safehouse.", 4.0)
	_near_realtor = near_realtor

	# Inside the trading-floor office: detect the monitor desk and the exit pad.
	if in_trading_floor:
		var td := Vector2(CityWorld.OFFICE_DESK.x - player_pos.x,
			CityWorld.OFFICE_DESK.z - player_pos.z).length()
		_near_trade_desk = td < 3.0
		var xd := Vector2(CityWorld.OFFICE_EXIT.x - player_pos.x,
			CityWorld.OFFICE_EXIT.z - player_pos.z).length()
		_near_office_exit = xd < 2.4


# ---------------- Car ----------------
func _update_car(v: Dictionary, dt: float) -> void:
	# Held on the grid until the lights go out.
	if RaceManager.state == "countdown":
		v.speed = 0.0
		car_drifting = false
		v.node.position = v.pos
		v.node.rotation.y = v.yaw
		return
	var accel := (1.0 if _key(KEY_W) else 0.0) - (1.0 if _key(KEY_S) else 0.0)
	var turn := (1.0 if _key(KEY_A) else 0.0) - (1.0 if _key(KEY_D) else 0.0)
	var boost := 1.7 if _key(KEY_SHIFT) else 1.0
	var handbrake := _key(KEY_SPACE)
	car_drifting = handbrake and absf(v.speed) > 12.0 and turn != 0.0

	# Accel scales with the car's top speed so it can actually fight drag up to
	# max_speed — a fixed force used to stall every car out near 210 km/h.
	v.speed += accel * v.max_speed * 0.6 * boost * dt
	v.speed *= 1.0 - dt * (4.0 if handbrake else 0.6)
	var max_s: float = v.max_speed * boost
	v.speed = clamp(v.speed, -max_s / 2.0, max_s)
	if abs(v.speed) > 1.0 and randf() < 0.15:
		AudioFX.engine_rev(absf(v.speed) / maxf(v.max_speed, 1.0))
	if abs(v.speed) > 0.5:
		var sgn := 1.0 if v.speed > 0.0 else -1.0
		v.yaw += turn * 1.8 * dt * sgn * min(1.0, abs(v.speed) / 6.0)

	var dx: float = sin(v.yaw) * v.speed * dt
	var dz: float = cos(v.yaw) * v.speed * dt
	if not world.collides_at(v.pos.x + dx, v.pos.z, 1.2, v.pos.y):
		v.pos.x += dx
	else:
		_spawn_sparks(v.pos.x, 0.8, v.pos.z, 4)
		v.hp -= abs(v.speed) * 0.3
		v.speed *= -0.3
		AudioFX.hit()
	if not world.collides_at(v.pos.x, v.pos.z + dz, 1.2, v.pos.y):
		v.pos.z += dz
	else:
		_spawn_sparks(v.pos.x, 0.8, v.pos.z, 4)
		v.hp -= abs(v.speed) * 0.3
		v.speed *= -0.3
		AudioFX.hit()
	# Ride up and over the elevated river bridges.
	v.pos.y = world.surface_height(v.pos.x, v.pos.z)
	v.node.position = v.pos
	v.node.rotation.y = v.yaw

	# A bike is open — show the player sitting astride it.
	if v.get("style", "") == "bike":
		_seat_bike_rider(v)

	# Pit lane — slow down inside it and the car repairs itself.
	if world.track != null and world.track.in_pit_lane(v.pos) \
		and absf(v.speed) < 8.0 and v.hp < v.max_hp:
		v.hp = minf(v.max_hp, v.hp + 26.0 * dt)

	for o in npcs + cops + guards + vips:
		if o.hp <= 0.0:
			continue
		if o.pos.distance_to(v.pos) < 1.5 and abs(v.speed) > 3.0:
			o.hp -= abs(v.speed) * 4.0
			_spawn_blood(o.pos.x, 1.0, o.pos.z, 12)
			_raise_wanted(1.0)
	player_pos = v.pos

	if v.hp <= 0.0 and not v.burning:
		v.burning = true
		v.burn_timer = 2.0
	if v.burning:
		v.burn_timer -= dt
		_spawn_fire(v.pos.x, 0.0, v.pos.z, 2)
		if v.burn_timer <= 0.0:
			var ex: float = v.pos.x
			var ez: float = v.pos.z
			var mine: bool = in_car == v
			_explode(ex, 1.0, ez)
			v.node.queue_free()
			vehicles.erase(v)
			if mine:
				in_car = null
				player_pos = Vector3(ex, 0, ez)
				if world.collides_at(ex, ez, 0.5):
					var s := world.find_safe_spawn()
					player_pos = Vector3(s.x, 0, s.y)
				player_hp -= 30.0
				player_node.visible = true


## Pose the player astride a bike — seated on the saddle, hands on the bars.
func _seat_bike_rider(v: Dictionary) -> void:
	player_node.visible = true
	var fwd := Vector3(sin(v.yaw), 0.0, cos(v.yaw))
	# Sit slightly back from the bike's centre, on the saddle.
	player_node.position = Vector3(v.pos.x, v.pos.y, v.pos.z) - fwd * 0.35
	player_node.rotation.y = v.yaw
	if player_node.has_meta("limbs"):
		var lim: Dictionary = player_node.get_meta("limbs")
		# Legs tucked forward to the pegs, arms reaching the handlebars.
		lim.legL.rotation.x = 0.95
		lim.legR.rotation.x = 0.95
		lim.armL.rotation.x = -1.05
		lim.armR.rotation.x = -1.05


# ---------------- Plane ----------------
func _update_plane(v: Dictionary, dt: float) -> void:
	# A/D yaw (banked turn), Up/Down arrows pitch the nose. The engine spools
	# up on its own toward cruise power, so the plane always builds flying
	# speed — just hold Up to climb. W boosts, S throttles back.
	var thrust := (1.0 if _key(KEY_W) else 0.0) - (1.0 if _key(KEY_S) else 0.0)
	var turn := (1.0 if _key(KEY_A) else 0.0) - (1.0 if _key(KEY_D) else 0.0)
	var pitch_input := (1.0 if _key(KEY_UP) else 0.0) - (1.0 if _key(KEY_DOWN) else 0.0)

	# Throttle auto-spools toward cruise (0.72); W boosts to full, S throttles
	# back. The plane is never stuck idling — it always accelerates to fly.
	var target_throttle: float = clampf(0.72 + thrust * 0.28, 0.0, 1.0)
	v.throttle = move_toward(v.throttle, target_throttle, 0.9 * dt)
	v.speed = move_toward(v.speed, v.throttle * v.max_speed, v.max_speed * 0.6 * dt)

	# Pitch — Up raises the nose, Down drops it; snaps back level when released.
	v.pitch += pitch_input * 0.8 * dt
	if pitch_input == 0.0:
		v.pitch = move_toward(v.pitch, 0.0, 1.2 * dt)
	v.pitch = clamp(v.pitch, -0.55, 0.55)

	# Yaw — a banked turn that needs airspeed; roll the airframe into it.
	if v.speed > 5.0:
		v.yaw += turn * 0.7 * dt
	v.roll = lerp(v.roll, -turn * 0.5, dt * 3.0)

	# Vertical motion: above takeoff speed the nose sets climb/descent; below
	# it the wings can't carry the plane and it sinks.
	var takeoff_speed := 14.0
	var vy: float = sin(v.pitch) * v.speed
	if v.speed < takeoff_speed:
		vy -= (takeoff_speed - v.speed) * 0.6
	v.vy = vy
	v.pos.y += vy * dt
	if v.pos.y < 0.0:
		v.pos.y = 0.0
	if v.pos.y > v.max_alt:
		v.pos.y = v.max_alt
	v.on_ground = v.pos.y <= 0.15

	# Horizontal travel along the nose heading.
	var h: float = cos(v.pitch)
	var dx: float = sin(v.yaw) * h * v.speed * dt
	var dz: float = cos(v.yaw) * h * v.speed * dt
	if not world.collides_at(v.pos.x + dx, v.pos.z, v.radius, v.pos.y):
		v.pos.x += dx
	else:
		v.speed *= 0.3
		v.hp -= 5.0
	if not world.collides_at(v.pos.x, v.pos.z + dz, v.radius, v.pos.y):
		v.pos.z += dz
	else:
		v.speed *= 0.3
		v.hp -= 5.0

	v.node.position = v.pos
	# Nose points +Z, so a positive rotation.x would tip the nose DOWN — negate
	# the pitch so holding Up rotates the nose up into a proper climb.
	v.node.rotation = Vector3(-v.pitch, v.yaw, v.roll)
	player_pos = v.pos

	if v.hp <= 0.0 and not v.burning:
		v.burning = true
		v.burn_timer = 2.0
	if v.burning:
		v.burn_timer -= dt
		_spawn_fire(v.pos.x, v.pos.y, v.pos.z, 3)
		if v.burn_timer <= 0.0:
			var ex: float = v.pos.x
			var ey: float = v.pos.y
			var ez: float = v.pos.z
			var mine: bool = in_car == v
			_explode(v.pos.x, v.pos.y, v.pos.z)
			v.node.queue_free()
			vehicles.erase(v)
			if mine:
				in_car = null
				if ey > 6.0:
					_deploy_parachute(Vector3(ex, ey, ez))
				else:
					player_pos = Vector3(ex, 0, ez)
					player_hp -= 30.0
					player_node.visible = true


# ---------------- Helicopter ----------------
func _update_helicopter(v: Dictionary, dt: float) -> void:
	# A/D yaw, W/S fly forward/back, Up/Down climb/descend. Release every key
	# and the helicopter just hovers in place — vertical takeoff, no runway.
	var fwd := (1.0 if _key(KEY_W) else 0.0) - (1.0 if _key(KEY_S) else 0.0)
	var turn := (1.0 if _key(KEY_A) else 0.0) - (1.0 if _key(KEY_D) else 0.0)
	var lift := (1.0 if _key(KEY_UP) else 0.0) - (1.0 if _key(KEY_DOWN) else 0.0)

	v.yaw += turn * 1.4 * dt

	# Vertical: Up climbs, Down descends, neutral holds a steady hover.
	v.vy = move_toward(v.vy, lift * 24.0, 48.0 * dt)
	v.pos.y = clampf(v.pos.y + v.vy * dt, 0.0, v.max_alt)
	if v.pos.y <= 0.0 and v.vy < 0.0:
		v.vy = 0.0
	v.on_ground = v.pos.y <= 0.15

	# Cyclic only bites once airborne, so it lifts off before it can slide.
	var airborne: bool = v.pos.y > 1.2
	var target_speed: float = (fwd * v.max_speed) if airborne else 0.0
	v.speed = move_toward(v.speed, target_speed, v.max_speed * 1.1 * dt)

	# Cosmetic tilt: nose dips forward under power, banks into turns.
	v.pitch = lerp(v.pitch, -fwd * 0.22, dt * 4.0)
	v.roll = lerp(v.roll, -turn * 0.3, dt * 4.0)

	var dx: float = sin(v.yaw) * v.speed * dt
	var dz: float = cos(v.yaw) * v.speed * dt
	if not world.collides_at(v.pos.x + dx, v.pos.z, v.radius, v.pos.y):
		v.pos.x += dx
	else:
		v.speed *= 0.2
		v.hp -= 4.0
	if not world.collides_at(v.pos.x, v.pos.z + dz, v.radius, v.pos.y):
		v.pos.z += dz
	else:
		v.speed *= 0.2
		v.hp -= 4.0

	v.node.position = v.pos
	v.node.rotation = Vector3(v.pitch, v.yaw, v.roll)
	player_pos = v.pos

	# Spin the rotors — faster while climbing or moving.
	var spin: float = 22.0 + absf(v.speed) * 0.4
	if v.rotor != null:
		v.rotor.rotation.y += dt * spin
	if v.tail_rotor != null:
		v.tail_rotor.rotation.x += dt * spin * 1.5

	if v.hp <= 0.0 and not v.burning:
		v.burning = true
		v.burn_timer = 2.0
	if v.burning:
		v.burn_timer -= dt
		_spawn_fire(v.pos.x, v.pos.y, v.pos.z, 3)
		if v.burn_timer <= 0.0:
			var ex: float = v.pos.x
			var ey: float = v.pos.y
			var ez: float = v.pos.z
			var mine: bool = in_car == v
			_explode(v.pos.x, v.pos.y, v.pos.z)
			v.node.queue_free()
			vehicles.erase(v)
			if mine:
				in_car = null
				if ey > 6.0:
					_deploy_parachute(Vector3(ex, ey, ez))
				else:
					player_pos = Vector3(ex, 0, ez)
					player_hp -= 30.0
					player_node.visible = true


# ---------------- Enter / exit ----------------
func _try_enter_exit() -> void:
	if in_car != null:
		var v = in_car
		if v.get("is_rocket", false):
			_exit_rocket(v)
			return
		if v.get("moon", false):
			in_car = null
			cam_dist = 6.5
			player_pos = Vector3(v.pos.x + 3.6, CityWorld.MOON_Y, v.pos.z)
			player_node.visible = true
			_show_objective("Stepped off the moon buggy.")
			return
		if v.is_plane and v.pos.y > 4.0:
			# Bail out — parachute down; the empty plane is lost.
			var bail := Vector3(v.pos.x, v.pos.y, v.pos.z)
			v.node.queue_free()
			vehicles.erase(v)
			in_car = null
			_deploy_parachute(bail)
			return
		if v.get("is_boat", false):
			# A boat can only be left at a dock — step onto the planks.
			var bd: Vector3 = world.nearest_dock(v.pos)
			if bd.x < 1e8 and Vector2(bd.x - v.pos.x, bd.z - v.pos.z).length() < 9.0:
				in_car = null
				cam_dist = 6.5
				player_pos = Vector3(bd.x, 0, bd.z)
				player_node.visible = true
				_show_objective("Stepped onto the dock.")
			else:
				_show_objective("Steer up to a dock to step off the boat.", 3.0)
			return
		in_car = null
		cam_dist = 6.5
		var exit_x: float = v.pos.x + cos(v.yaw + PI / 2.0) * 2.0
		var exit_z: float = v.pos.z + sin(v.yaw + PI / 2.0) * 2.0
		player_pos = Vector3(exit_x, world.surface_height(exit_x, exit_z), exit_z)
		player_node.visible = true
		_show_objective("On foot. Mouse to aim, click to shoot. Hold Space to zoom into a first-person aim.")
		return
	var best = null
	var best_d := INF
	for v in vehicles:
		if v.burning:
			continue
		if v.get("motorcade", false):
			continue                          # the President's convoy can't be commandeered
		if absf(v.pos.y - player_pos.y) > 40.0:
			continue                          # can't board across a big height gap
		var d: float = Vector2(v.pos.x - player_pos.x, v.pos.z - player_pos.z).length()
		var max_d: float = (5.0 + v.radius) if v.is_plane else 4.0
		if d < max_d and d < best_d:
			best_d = d
			best = v
	if best != null:
		in_car = best
		cam_yaw = best.yaw + PI
		# Open vehicles (the bike) keep the rider on show; closed ones hide them.
		player_node.visible = best.get("style", "") == "bike"
		if best.get("is_rocket", false):
			cam_dist = best.get("cam_dist", 28.0)
			if space_state == "moon":
				space_state = "moon_ascent"
				_show_objective("Lift off — hold W to fly home to Earth.", 6.0)
			else:
				space_state = "ascent"
				_show_objective("ROCKET — hold W to launch, A/D steer. Climb to space, then the Moon.", 9.0)
		elif best.get("is_heli", false):
			cam_dist = best.get("cam_dist", 15.0)
			_show_objective("Helicopter: hold Up to lift straight off and climb, Down to descend. W/S fly forward/back, A/D turn. Release everything to hover. F bails out (parachute).", 8.0)
		elif best.get("is_boat", false):
			cam_dist = 7.5
			_show_objective("Boat: W/S throttle, A/D steer. Cruise the river and the bay — F to step off at a dock.", 7.0)
		elif best.is_plane:
			cam_dist = best.get("cam_dist", 12.0)
			_show_objective("Plane: the engine spools up on its own - just hold Up to climb once rolling. A/D turn, W/S throttle, Down to descend. F bails out (parachute).", 8.0)
		else:
			cam_dist = 6.5
			_show_objective("WASD to drive. SHIFT boost. SPACE handbrake. F to exit.")


# ---------------- Parachute ----------------
func _deploy_parachute(at: Vector3) -> void:
	parachuting = true
	player_pos = at
	player_yaw = 0.0
	player_node.position = player_pos
	player_node.visible = true
	cam_dist = 7.0
	if para_node != null:
		para_node.queue_free()
	para_node = _make_parachute()
	add_child(para_node)
	_show_objective("Parachute open! WASD to steer your drift — you'll land safely.", 5.0)


func _update_parachute(dt: float) -> void:
	var mx := (1.0 if _key(KEY_D) else 0.0) - (1.0 if _key(KEY_A) else 0.0)
	var mz := (1.0 if _key(KEY_W) else 0.0) - (1.0 if _key(KEY_S) else 0.0)
	var l := sqrt(mx * mx + mz * mz)
	if l > 0.0:
		mx /= l
		mz /= l
		var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
		var rgt := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
		var dx := (rgt.x * mx + fwd.x * mz) * 7.0 * dt
		var dz := (rgt.z * mx + fwd.z * mz) * 7.0 * dt
		if not world.collides_at(player_pos.x + dx, player_pos.z, 0.4, player_pos.y):
			player_pos.x += dx
		if not world.collides_at(player_pos.x, player_pos.z + dz, 0.4, player_pos.y):
			player_pos.z += dz
		player_yaw = atan2(dx, dz)
	player_pos.y -= 9.0 * dt
	if player_pos.y <= 0.0:
		player_pos.y = 0.0
		parachuting = false
		if para_node != null:
			para_node.queue_free()
			para_node = null
		_show_objective("Touched down safely.", 3.0)
	player_node.position = player_pos
	player_node.rotation.y = player_yaw
	Human.animate(player_node, walk_phase, false, 0.0, 0.0)
	if para_node != null:
		para_node.position = player_pos + Vector3(0, 5.4, 0)


func _make_parachute() -> Node3D:
	var n := Node3D.new()
	var canopy := Build.cyl(0.0, 4.2, 2.0, 16, Build.mat(Build.hex(0xe05a2a), 0.7))
	n.add_child(canopy)
	var line_m := Build.mat(Build.hex(0x2a2a2e), 0.6)
	for a in 4:
		var ang := float(a) / 4.0 * TAU + PI / 4.0
		var line := Build.box(0.08, 5.2, 0.08, line_m)
		line.position = Vector3(cos(ang) * 2.4, -2.8, sin(ang) * 2.4)
		n.add_child(line)
	return n


# =====================================================================
# Iron Man suit
# =====================================================================
## Builds the armoured humanoid — same limb layout as Human (so the walk
## animation works), plus glowing arc reactor, hand repulsors and helmet eyes.
## meta "pieces" holds every plate in feet-to-head order for the suit-up reveal.
func _build_iron_suit(tier := 1) -> Node3D:
	var g := Node3D.new()
	# Each tier wears its own livery: classic red/gold Mark III, crimson and
	# silver Mark VI, gunmetal War Machine (which also gets a shoulder cannon).
	var primary: StandardMaterial3D
	var secondary: StandardMaterial3D
	var dark: StandardMaterial3D
	match tier:
		2:
			primary = Build.mat(Build.hex(0x9c1216), 0.32, 0.55)
			secondary = Build.mat(Build.hex(0xc6cad2), 0.3, 0.8)
			dark = Build.mat(Build.hex(0x26262c), 0.5, 0.5)
		3:
			primary = Build.mat(Build.hex(0x52565d), 0.4, 0.7)
			secondary = Build.mat(Build.hex(0x303338), 0.45, 0.6)
			dark = Build.mat(Build.hex(0x1a1b20), 0.5, 0.5)
		4:
			# Hulkbuster — heavy red-and-gold assault armour.
			primary = Build.mat(Build.hex(0xb83838), 0.34, 0.55)
			secondary = Build.mat(Build.hex(0xd0a840), 0.3, 0.7)
			dark = Build.mat(Build.hex(0x2a2a30), 0.5, 0.5)
		_:
			primary = Build.mat(Build.hex(0xb01a1a), 0.34, 0.55)
			secondary = Build.mat(Build.hex(0xe0ad28), 0.3, 0.7)
			dark = Build.mat(Build.hex(0x2a2a30), 0.5, 0.5)
	var glow := Build.emissive(Build.hex(0x9fe9ff), Build.hex(0x9fe9ff), 4.5)
	var eyeglow := Build.emissive(Build.hex(0xeaffff), Build.hex(0xd6f4ff), 4.0)
	var pieces: Array = []

	var legL := Node3D.new()
	legL.position = Vector3(-0.16, 1.0, 0)
	g.add_child(legL)
	var legR := Node3D.new()
	legR.position = Vector3(0.16, 1.0, 0)
	g.add_child(legR)
	for leg in [legL, legR]:
		var thigh := Build.box(0.27, 0.46, 0.29, primary)
		thigh.position.y = -0.225
		leg.add_child(thigh)
		var shin := Build.box(0.25, 0.46, 0.27, secondary)
		shin.position.y = -0.675
		leg.add_child(shin)
		var boot := Build.box(0.27, 0.15, 0.42, primary)
		boot.position = Vector3(0, -0.95, 0.06)
		leg.add_child(boot)
		pieces.append(boot)
		pieces.append(shin)
		pieces.append(thigh)

	var pelvis := Build.box(0.5, 0.26, 0.33, dark)
	pelvis.position.y = 1.06
	g.add_child(pelvis)
	pieces.append(pelvis)
	var abs_plate := Build.box(0.5, 0.3, 0.36, secondary)
	abs_plate.position.y = 1.14
	g.add_child(abs_plate)
	pieces.append(abs_plate)
	var torso := Build.box(0.64, 0.72, 0.4, primary)
	torso.position.y = 1.42
	g.add_child(torso)
	pieces.append(torso)
	var reactor := Build.cyl(0.1, 0.1, 0.09, 14, glow)
	reactor.rotation.x = PI / 2.0
	reactor.position = Vector3(0, 1.55, 0.21)
	g.add_child(reactor)
	pieces.append(reactor)
	var shoulders := Build.box(0.88, 0.24, 0.43, primary)
	shoulders.position.y = 1.76
	g.add_child(shoulders)
	pieces.append(shoulders)

	# War Machine's shoulder-mounted cannon.
	if tier >= 3:
		var mount := Build.box(0.26, 0.24, 0.36, dark)
		mount.position = Vector3(0.34, 2.0, -0.02)
		g.add_child(mount)
		pieces.append(mount)
		var barrel := Build.cyl(0.08, 0.08, 0.54, 10, dark)
		barrel.rotation.x = PI / 2.0
		barrel.position = Vector3(0.34, 2.02, 0.34)
		g.add_child(barrel)
		pieces.append(barrel)

	var armL := Node3D.new()
	armL.position = Vector3(-0.43, 1.74, 0)
	g.add_child(armL)
	var armR := Node3D.new()
	armR.position = Vector3(0.43, 1.74, 0)
	g.add_child(armR)
	for arm in [armL, armR]:
		var upper := Build.box(0.19, 0.42, 0.19, primary)
		upper.position.y = -0.21
		arm.add_child(upper)
		var fore := Build.box(0.18, 0.38, 0.18, secondary)
		fore.position.y = -0.6
		arm.add_child(fore)
		var hand := Build.box(0.17, 0.15, 0.17, dark)
		hand.position.y = -0.85
		arm.add_child(hand)
		var palm := Build.cyl(0.075, 0.075, 0.05, 12, glow)
		palm.position = Vector3(0, -0.92, 0.02)
		arm.add_child(palm)
		pieces.append(upper)
		pieces.append(fore)
		pieces.append(hand)
		pieces.append(palm)

	var headG := Node3D.new()
	headG.position.y = 1.93
	g.add_child(headG)
	var helmet := Build.box(0.35, 0.37, 0.35, primary)
	headG.add_child(helmet)
	pieces.append(helmet)
	var face := Build.box(0.29, 0.24, 0.07, secondary)
	face.position = Vector3(0, -0.03, 0.16)
	headG.add_child(face)
	pieces.append(face)
	for ex in [-0.075, 0.075]:
		var eye := Build.box(0.075, 0.035, 0.03, eyeglow)
		eye.position = Vector3(ex, 0.04, 0.19)
		headG.add_child(eye)
		pieces.append(eye)

	var rest: Array = []
	for p in pieces:
		rest.append(p.position)
	g.set_meta("limbs", {"armL": armL, "armR": armR, "legL": legL, "legR": legR, "headG": headG})
	g.set_meta("pieces", pieces)
	g.set_meta("rest", rest)
	# The Hulkbuster is a massive rig — wear it large.
	if tier >= 4:
		g.scale = Vector3(1.5, 1.5, 1.5)
	return g


## Place the suit, fully assembled, on open ground near the player's spawn.
func _spawn_iron_suit() -> void:
	suit_node = _build_iron_suit()
	add_child(suit_node)
	var spot := Vector2(player_pos.x + 11.0, player_pos.z)
	for ring in range(7, 60):
		var found := false
		for i in ring * 3:
			var a := float(i) / float(ring * 3) * TAU
			var x := player_pos.x + cos(a) * ring * 1.4
			var z := player_pos.z + sin(a) * ring * 1.4
			if abs(x) > CityWorld.WORLD_HALF - 4.0 or abs(z) > CityWorld.WORLD_HALF - 4.0:
				continue
			if not world.collides_at(x, z, 1.5):
				spot = Vector2(x, z)
				found = true
				break
		if found:
			break
	suit_node.position = Vector3(spot.x, 0.0, spot.y)
	suit_state = "none"
	suit_armed = true


## Rebuild the parked suit so its model matches the currently-owned tier.
## Only safe while the suit is parked ("none"), not mid-flight.
func _refresh_suit_model() -> void:
	if suit_node == null:
		return
	var pos := suit_node.position
	var rot := suit_node.rotation
	suit_node.queue_free()
	suit_node = _build_iron_suit(Garage.suit_tier)
	add_child(suit_node)
	suit_node.position = pos
	suit_node.rotation = rot


## The Y of the surface the player stands on — the Moon when up there, else 0.
func _ground_y() -> float:
	return CityWorld.MOON_Y if space_state == "moon" else 0.0


func _begin_suit() -> void:
	_refresh_suit_model()                # wear the model of the owned tier
	suit_state = "suiting"
	suit_timer = 0.0
	suit_armed = false
	var gy := _ground_y()
	player_pos.y = gy
	suit_node.position = Vector3(player_pos.x, gy, player_pos.z)
	suit_node.rotation = Vector3(0, player_yaw, 0)
	cam_dist = 9.0
	var pieces: Array = suit_node.get_meta("pieces")
	suit_full_time = pieces.size() * SUIT_STAGGER + SUIT_GROW
	# Every plate starts hidden, full size; the body stays visible and each
	# plate flies down and clamps onto it in turn.
	for p in pieces:
		p.scale = Vector3.ONE
		p.visible = false
	_show_objective("Suiting up...", 3.0)
	AudioFX.hit()


func _unsuit() -> void:
	suit_state = "none"
	suit_armed = false
	suit_vy = 0.0
	var gy := _ground_y()
	player_pos.y = gy
	suit_node.position = Vector3(player_pos.x, gy, player_pos.z)
	suit_node.rotation = Vector3.ZERO
	var pieces: Array = suit_node.get_meta("pieces")
	var rest: Array = suit_node.get_meta("rest")
	for i in pieces.size():
		pieces[i].scale = Vector3.ONE
		pieces[i].visible = true
		pieces[i].position = rest[i]
	player_node.position = player_pos
	player_node.visible = true
	cam_dist = 6.5
	_show_objective("Suit powered down — press V to call it back, or step onto it, to suit up again.", 4.0)


func _update_suiting(dt: float) -> void:
	suit_timer += dt
	var pieces: Array = suit_node.get_meta("pieces")
	var rest: Array = suit_node.get_meta("rest")
	suit_node.position = Vector3(player_pos.x, _ground_y(), player_pos.z)
	suit_node.rotation = Vector3(0, player_yaw, 0)
	# The body stands still, visible, while the plates clamp onto it.
	player_node.position = player_pos
	player_node.rotation.y = player_yaw
	Human.animate(player_node, walk_phase, false, 0.0, 0.0)
	for i in pieces.size():
		var start: float = i * SUIT_STAGGER
		pieces[i].visible = suit_timer >= start
		var t: float = clampf((suit_timer - start) / SUIT_GROW, 0.0, 1.0)
		var land: float = 1.0 - pow(1.0 - t, 3.0)         # ease-out: clicks into place
		pieces[i].position = rest[i] + Vector3(0, 3.6 * (1.0 - land), 0)
	if randf() < 0.5:
		_spawn_sparks(player_pos.x + (randf() - 0.5) * 0.9, 0.5 + randf() * 1.9,
			player_pos.z + (randf() - 0.5) * 0.9, 1)
	if suit_timer >= suit_full_time:
		for i in pieces.size():
			pieces[i].visible = true
			pieces[i].position = rest[i]
		suit_state = "on"
		player_node.visible = false
		_show_objective("SUIT ONLINE. UP/DOWN to fly up/down (hovers when you let go), WASD to move, SHIFT boost, SPACE to zoom aim, L-click repulsors, R-click missiles. F powers down.", 10.0)


## Call the suit from afar — every plate detaches from the parked armour and
## flies across the map to clamp onto the player, feet-first.
func _summon_suit() -> void:
	if suit_node == null or suit_state != "none" or not suit_armed:
		return
	var origin := suit_node.position             # the parked armour's spot
	_refresh_suit_model()                        # wear the model of the owned tier
	origin = suit_node.position                  # _refresh rebuilds at the same spot
	suit_state = "summoning"
	suit_timer = 0.0
	suit_armed = false
	var gy := _ground_y()
	player_pos.y = gy
	suit_node.position = Vector3(player_pos.x, gy, player_pos.z)
	suit_node.rotation = Vector3(0, player_yaw, 0)
	cam_dist = 9.0
	var pieces: Array = suit_node.get_meta("pieces")
	# Where the armour streaks in from. On the Moon the parked suit is back on
	# Earth, so the plates come down from just above the player instead.
	var origin_xz := Vector3(origin.x, gy, origin.z)
	if space_state == "moon":
		origin_xz = Vector3(player_pos.x, gy + 40.0, player_pos.z)
	var start: Vector3 = suit_node.to_local(origin_xz)
	var starts: Array = []
	for i in pieces.size():
		var scatter := Vector3((randf() - 0.5) * 3.0, randf() * 2.5,
			(randf() - 0.5) * 3.0)
		starts.append(start + scatter)
		pieces[i].scale = Vector3.ONE
		pieces[i].visible = true
		pieces[i].position = start + scatter
	suit_node.set_meta("summon_starts", starts)
	suit_full_time = pieces.size() * SUIT_SUMMON_STAGGER + SUIT_SUMMON_FLIGHT
	_spawn_sparks(origin_xz.x, gy + 1.0, origin_xz.z, 6)
	_show_objective("Suit inbound — armour incoming!", 3.0)
	AudioFX.hit()


func _update_summoning(dt: float) -> void:
	suit_timer += dt
	var pieces: Array = suit_node.get_meta("pieces")
	var rest: Array = suit_node.get_meta("rest")
	var starts: Array = suit_node.get_meta("summon_starts")
	suit_node.position = Vector3(player_pos.x, _ground_y(), player_pos.z)
	suit_node.rotation = Vector3(0, player_yaw, 0)
	# The body stands ready, visible, while the armour streaks in around it.
	player_node.position = player_pos
	player_node.rotation.y = player_yaw
	player_node.visible = true
	Human.animate(player_node, walk_phase, false, 0.0, 0.0)
	for i in pieces.size():
		var start_t: float = i * SUIT_SUMMON_STAGGER
		var t: float = clampf((suit_timer - start_t) / SUIT_SUMMON_FLIGHT, 0.0, 1.0)
		var land: float = 1.0 - pow(1.0 - t, 3.0)        # ease-out: clicks home
		var p: Vector3 = (starts[i] as Vector3).lerp(rest[i] as Vector3, land)
		p.y += sin(land * PI) * 3.0                       # swoop up, then down on
		pieces[i].position = p
		# Bright streak trailing each plate still in flight.
		if t > 0.0 and t < 1.0 and randf() < 0.7:
			var wp: Vector3 = pieces[i].global_position
			_spawn_particle(wp.x, wp.y, wp.z, 0x9fe9ff, 0.26,
				(randf() - 0.5) * 1.2, (randf() - 0.5) * 1.2, (randf() - 0.5) * 1.2)
	if suit_timer >= suit_full_time:
		for i in pieces.size():
			pieces[i].visible = true
			pieces[i].position = rest[i]
		suit_state = "on"
		player_node.visible = false
		_show_objective("SUIT ONLINE. UP/DOWN to fly up/down (hovers when you let go), WASD to move, SHIFT boost, SPACE to zoom aim, L-click repulsors, R-click missiles. F powers down.", 10.0)


func _update_suit(dt: float) -> void:
	var st := Garage.suit_stats()
	var ascend := (1.0 if _key(KEY_UP) else 0.0) - (1.0 if _key(KEY_DOWN) else 0.0)
	var mx := (1.0 if _key(KEY_D) else 0.0) - (1.0 if _key(KEY_A) else 0.0)
	var mz := (1.0 if _key(KEY_W) else 0.0) - (1.0 if _key(KEY_S) else 0.0)

	# Vertical: Up climbs, Down descends, neither holds a steady hover. The
	# floor follows the surface — y=0 on Earth, MOON_Y up on the Moon.
	var gy := _ground_y()
	suit_vy = move_toward(suit_vy, ascend * st.fly_v, 46.0 * dt)
	player_pos.y = clampf(player_pos.y + suit_vy * dt, gy, gy + 220.0)
	if player_pos.y <= gy:
		player_pos.y = gy
		suit_vy = maxf(suit_vy, 0.0)
	var airborne: bool = player_pos.y > gy + 0.7

	# Horizontal travel — relative to where the camera is looking.
	var l := sqrt(mx * mx + mz * mz)
	if l > 0.0:
		mx /= l
		mz /= l
		var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
		var rgt := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
		var spd: float = st.fly_h if airborne else 7.0
		if _key(KEY_SHIFT):
			spd *= 1.7
		var dx := (rgt.x * mx + fwd.x * mz) * spd * dt
		var dz := (rgt.z * mx + fwd.z * mz) * spd * dt
		if space_state == "moon":
			# The lunar surface is open — no city collision up here.
			player_pos.x += dx
			player_pos.z += dz
		else:
			if not world.collides_at(player_pos.x + dx, player_pos.z, 0.6, player_pos.y):
				player_pos.x += dx
			if not world.collides_at(player_pos.x, player_pos.z + dz, 0.6, player_pos.y):
				player_pos.z += dz
		player_yaw = atan2(dx, dz)

	suit_node.position = player_pos
	suit_node.rotation = Vector3(0, player_yaw, 0)
	Human.animate(suit_node, walk_phase, l > 0.0 and not airborne, 0.6, 0.4)

	# Repulsor jets blast from the boots while airborne.
	if airborne:
		for foot in [-0.16, 0.16]:
			_spawn_particle(player_pos.x + foot, player_pos.y + 0.05, player_pos.z,
				0x8fe6ff, 0.3, (randf() - 0.5) * 1.5, -7.0 - randf() * 4.0,
				(randf() - 0.5) * 1.5)

	# Repulsors (left mouse) and missiles (right mouse). Missiles are only
	# online from the Mark VI up — the Mark III fires repulsors alone.
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
			and _now - repulsor_at > st.repulsor_cd:
			repulsor_at = _now
			_fire_repulsor(st)
		if st.has_missiles and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) \
			and _now - missile_at > st.missile_cd:
			missile_at = _now
			_fire_missile(st)


func _fire_repulsor(st: Dictionary) -> void:
	var dir := (-camera.global_transform.basis.z).normalized()
	var from := Vector3(player_pos.x, player_pos.y + 1.1, player_pos.z)
	var w := {"range": REPULSOR_RANGE, "damage": st.repulsor_dmg,
		"explosive": false, "pellets": 1.0}
	_spawn_bullet(from, dir, w, "player", _repulsor_mat, 170.0, 0.2)
	_spawn_sparks(from.x + dir.x, from.y + dir.y, from.z + dir.z, 2)
	AudioFX.shoot()


func _fire_missile(st: Dictionary) -> void:
	var dir := (-camera.global_transform.basis.z).normalized()
	var from := Vector3(player_pos.x, player_pos.y + 1.3, player_pos.z)
	var w := {"range": MISSILE_RANGE, "damage": st.missile_dmg,
		"explosive": true, "pellets": 1.0}
	_spawn_bullet(from, dir, w, "player", _missile_mat, 82.0, 0.36)
	AudioFX.shoot()


func _player_invuln() -> bool:
	return suit_state != "none"


# =====================================================================
# Weapons & combat
# =====================================================================
func _switch_weapon(delta: int) -> void:
	GameState.weapon_idx = (GameState.weapon_idx + delta + WeaponDB.LIST.size()) % WeaponDB.LIST.size()
	var w: Dictionary = WeaponDB.LIST[GameState.weapon_idx]
	var a := GameState.get_ammo(w)
	var txt: String = w.name
	if a != INF:
		txt += " - %d rnd" % int(a)
	if in_car != null:
		txt += " (use on foot)"
	_refresh_weapon_model()
	_show_objective(txt)


func _select_weapon(index: int) -> void:
	if index < 0 or index >= WeaponDB.LIST.size():
		return
	GameState.weapon_idx = index
	var w: Dictionary = WeaponDB.LIST[index]
	var a := GameState.get_ammo(w)
	var txt: String = w.name
	if a != INF:
		txt += " - %d rnd" % int(a)
	_refresh_weapon_model()
	_show_objective(txt)


## Rebuilds the weapon prop in the player's hand to match the current weapon.
func _refresh_weapon_model() -> void:
	if weapon_holder == null:
		return
	for c in weapon_holder.get_children():
		c.queue_free()
	weapon_holder.add_child(_weapon_model(GameState.weapon_idx))


## Builds a low-poly model for a weapon index, pointing +Z (the hand's forward).
func _weapon_model(idx: int) -> Node3D:
	var n := Node3D.new()
	var metal := Build.mat(Build.hex(0x2b2b30), 0.4, 0.6)
	var dark := Build.mat(Build.hex(0x18181c), 0.5)
	var wood := Build.mat(Build.hex(0x6a4528), 0.7)
	match idx:
		0:
			pass                                          # fists — empty hand
		1:                                                # knife
			var blade := Build.box(0.04, 0.1, 0.34, metal)
			blade.position.z = 0.22
			n.add_child(blade)
			n.add_child(Build.box(0.06, 0.1, 0.16, dark))
		2:                                                # pistol
			var slide := Build.box(0.09, 0.11, 0.34, metal)
			slide.position = Vector3(0, 0.05, 0.12)
			n.add_child(slide)
			var grip := Build.box(0.09, 0.22, 0.13, dark)
			grip.position.y = -0.1
			n.add_child(grip)
		3:                                                # revolver
			var body := Build.box(0.08, 0.1, 0.3, metal)
			body.position = Vector3(0, 0.05, 0.12)
			n.add_child(body)
			var drum := Build.cyl(0.09, 0.09, 0.14, 8, metal)
			drum.rotation.z = PI / 2.0
			drum.position = Vector3(0, 0.04, 0.06)
			n.add_child(drum)
			var grip := Build.box(0.08, 0.2, 0.12, wood)
			grip.position.y = -0.09
			n.add_child(grip)
		4:                                                # smg
			var body := Build.box(0.11, 0.17, 0.52, dark)
			body.position = Vector3(0, 0.05, 0.2)
			n.add_child(body)
			var barrel := Build.cyl(0.035, 0.035, 0.32, 8, metal)
			barrel.rotation.x = PI / 2.0
			barrel.position = Vector3(0, 0.07, 0.52)
			n.add_child(barrel)
			var grip := Build.box(0.09, 0.2, 0.11, dark)
			grip.position.y = -0.08
			n.add_child(grip)
			var mag := Build.box(0.06, 0.24, 0.1, metal)
			mag.position = Vector3(0, -0.13, 0.18)
			n.add_child(mag)
		5:                                                # rifle
			var body := Build.box(0.1, 0.17, 0.74, dark)
			body.position = Vector3(0, 0.05, 0.32)
			n.add_child(body)
			var barrel := Build.cyl(0.032, 0.032, 0.52, 8, metal)
			barrel.rotation.x = PI / 2.0
			barrel.position = Vector3(0, 0.08, 0.82)
			n.add_child(barrel)
			var stock := Build.box(0.09, 0.15, 0.28, wood)
			stock.position = Vector3(0, 0.02, -0.14)
			n.add_child(stock)
			var grip := Build.box(0.08, 0.19, 0.1, dark)
			grip.position.y = -0.07
			n.add_child(grip)
			var mag := Build.box(0.07, 0.26, 0.13, metal)
			mag.position = Vector3(0, -0.14, 0.24)
			n.add_child(mag)
		6:                                                # shotgun
			var body := Build.box(0.11, 0.15, 0.82, wood)
			body.position = Vector3(0, 0.04, 0.3)
			n.add_child(body)
			var barrel := Build.cyl(0.05, 0.05, 0.64, 8, metal)
			barrel.rotation.x = PI / 2.0
			barrel.position = Vector3(0, 0.1, 0.74)
			n.add_child(barrel)
			var grip := Build.box(0.08, 0.17, 0.1, dark)
			grip.position.y = -0.06
			n.add_child(grip)
		7:                                                # sniper
			var body := Build.box(0.09, 0.15, 0.96, dark)
			body.position = Vector3(0, 0.05, 0.42)
			n.add_child(body)
			var barrel := Build.cyl(0.028, 0.028, 0.74, 8, metal)
			barrel.rotation.x = PI / 2.0
			barrel.position = Vector3(0, 0.08, 1.06)
			n.add_child(barrel)
			var scope := Build.cyl(0.055, 0.055, 0.28, 10, dark)
			scope.rotation.x = PI / 2.0
			scope.position = Vector3(0, 0.2, 0.32)
			n.add_child(scope)
			var stock := Build.box(0.09, 0.17, 0.32, dark)
			stock.position = Vector3(0, 0.0, -0.14)
			n.add_child(stock)
		8:                                                # rpg
			var tube := Build.cyl(0.12, 0.13, 1.1, 12, dark)
			tube.rotation.x = PI / 2.0
			tube.position = Vector3(0, 0.06, 0.35)
			n.add_child(tube)
			var rear := Build.cyl(0.16, 0.16, 0.2, 12, metal)
			rear.rotation.x = PI / 2.0
			rear.position = Vector3(0, 0.06, -0.22)
			n.add_child(rear)
			var grip := Build.box(0.08, 0.21, 0.1, dark)
			grip.position = Vector3(0, -0.09, 0.18)
			n.add_child(grip)
	return n


func _update_shooting() -> void:
	if in_car != null or parachuting or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if suit_state != "none":          # the suit fires repulsors/missiles instead
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	var w: Dictionary = WeaponDB.LIST[GameState.weapon_idx]
	var ammo := GameState.get_ammo(w)
	if ammo != INF and ammo <= 0:
		if _now - last_fire_at > 0.75:
			last_fire_at = _now
			_show_objective("Out of ammo - Q or 1-9 to switch weapon")
	elif _now - last_fire_at > w.rate:
		last_fire_at = _now
		_fire_weapon(w)


## Tank cannon — L-click fires an explosive shell forward along the hull.
func _update_tank_fire() -> void:
	if in_car == null or in_car.get("style", "") != "tank":
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	if _now - last_fire_at < 1.4:
		return
	last_fire_at = _now
	var v: Dictionary = in_car
	var dir := Vector3(sin(v.yaw), 0.05, cos(v.yaw)).normalized()
	var tip: Vector3 = v.pos + dir * 5.2 + Vector3(0, 2.1, 0)
	var shell := {"range": 220.0, "damage": 120.0, "explosive": true, "pellets": 1.0}
	_spawn_bullet(tip, dir, shell, "player", _missile_mat, 98.0, 0.45)
	_raise_wanted(1.5)
	AudioFX.explode()


func _fire_weapon(w: Dictionary) -> void:
	var dir := -camera.global_transform.basis.z
	dir = dir.normalized()
	var from := Vector3(player_pos.x, 1.5, player_pos.z)

	if w.melee:
		var my := atan2(dir.x, dir.z)
		for o in npcs + vips:
			if o.hp <= 0.0:
				continue
			var rel: Vector3 = o.pos - player_pos
			if sqrt(rel.x * rel.x + rel.z * rel.z) < w.range:
				if abs(_ang_diff(atan2(rel.x, rel.z), my)) < 0.6:
					o.hp -= w.damage
					_spawn_blood(o.pos.x, 1.2, o.pos.z, 4)
					_raise_wanted(1.0)
		for o in cops + guards:
			if o.hp <= 0.0:
				continue
			var rel: Vector3 = o.pos - player_pos
			if sqrt(rel.x * rel.x + rel.z * rel.z) < w.range:
				if abs(_ang_diff(atan2(rel.x, rel.z), my)) < 0.6:
					o.hp -= w.damage
					_spawn_blood(o.pos.x, 1.2, o.pos.z, 4)
		AudioFX.hit()
		return

	if w.ammo != INF:
		GameState.weapon_ammo[w.name] -= 1
	for i in int(w.pellets):
		var d: Vector3 = dir + Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * float(w.spread)
		_spawn_bullet(from, d.normalized(), w, "player")
	if w.sound:
		AudioFX.shoot()


func _spawn_bullet(from: Vector3, dir: Vector3, w: Dictionary, source: String,
		mat: Material = null, speed := 120.0, bsize := 0.1) -> void:
	var mesh := Build.sphere(bsize, mat if mat != null else _bullet_mat)
	mesh.position = from
	add_child(mesh)
	bullets.append({
		"node": mesh, "pos": from, "vel": dir * speed,
		"life": w.range / speed, "damage": w.damage,
		"explosive": w.explosive, "source": source,
	})


func _update_bullets(dt: float) -> void:
	for b in bullets:
		b.pos += b.vel * dt
		b.life -= dt
		if world.collides_at(b.pos.x, b.pos.z, 0.1, b.pos.y) or b.pos.y < 0.0:
			if b.explosive:
				_apply_explosion(b.pos, b.damage, b.source)
			else:
				_spawn_sparks(b.pos.x, b.pos.y, b.pos.z, 3)
			b.life = 0.0
			continue
		if b.source == "player":
			var hit := false
			for t in npcs + cops + guards + vips:
				if t.hp <= 0.0:
					continue
				if b.pos.distance_to(_torso(t.pos)) < 1.0:
					t.hp -= b.damage
					_raise_wanted(0.4)
					_spawn_blood(t.pos.x, 1.2, t.pos.z, 4)
					AudioFX.hit()
					if b.explosive:
						_apply_explosion(b.pos, b.damage, b.source)
					b.life = 0.0
					hit = true
					break
			if not hit:
				for v in vehicles:
					if b.pos.distance_to(v.pos) < 2.5:
						v.hp -= b.damage * 0.3
						_spawn_sparks(b.pos.x, b.pos.y, b.pos.z, 4)
						b.life = 0.0
						break
		else:
			if player_hp > 0.0 and b.pos.distance_to(_torso(player_pos)) < 1.3:
				if _player_invuln():
					# Rounds spark harmlessly off the Iron Man armour.
					_spawn_sparks(b.pos.x, b.pos.y, b.pos.z, 5)
				else:
					var dmg: float = b.damage
					if player_armor > 0.0:
						var ab: float = min(player_armor, dmg * 0.7)
						player_armor -= ab
						dmg -= ab
					player_hp -= dmg
					_spawn_blood(player_pos.x, 1.2, player_pos.z, 4)
				AudioFX.hit()
				b.life = 0.0
			elif in_car != null and b.pos.distance_to(in_car.pos) < 2.0:
				in_car.hp -= b.damage * 0.5
				_spawn_sparks(b.pos.x, b.pos.y, b.pos.z, 4)
				b.life = 0.0
	var keep: Array = []
	for b in bullets:
		if b.life <= 0.0:
			b.node.queue_free()
		else:
			b.node.position = b.pos
			keep.append(b)
	bullets = keep


func _torso(pos: Vector3) -> Vector3:
	return Vector3(pos.x, 1.2, pos.z)


func _apply_explosion(center: Vector3, damage: float, source: String) -> void:
	_spawn_sparks(center.x, center.y, center.z, 14)
	var radius := 5.5
	if source == "player":
		for t in npcs + cops + guards + vips:
			if t.hp <= 0.0:
				continue
			var d: float = Vector2(t.pos.x - center.x, t.pos.z - center.z).length()
			if d < radius:
				var falloff := 1.0 - d / radius
				t.hp -= damage * (0.35 + falloff * 0.65)
				_raise_wanted(0.8)
				_spawn_blood(t.pos.x, 1.2, t.pos.z, 5)
	else:
		var d := Vector2(player_pos.x - center.x, player_pos.z - center.z).length()
		if d < radius:
			if _player_invuln():
				_spawn_sparks(player_pos.x, 1.2, player_pos.z, 6)
			else:
				var falloff := 1.0 - d / radius
				player_hp -= damage * (0.35 + falloff * 0.65)
				_spawn_blood(player_pos.x, 1.2, player_pos.z, 5)
	for v in vehicles:
		if Vector2(v.pos.x - center.x, v.pos.z - center.z).length() < radius + 1.0:
			v.hp -= damage * 0.4
			_spawn_sparks(v.pos.x, v.pos.y + 0.5, v.pos.z, 6)


func _explode(x: float, y: float, z: float) -> void:
	AudioFX.explode()
	for i in 60:
		var col: int = [0xff5733, 0xffaa33, 0xffe933].pick_random()
		_spawn_particle(x, y + 0.5, z, col, 0.8,
			(randf() - 0.5) * 10.0, randf() * 6.0, (randf() - 0.5) * 10.0)
	var dp := Vector2(player_pos.x - x, player_pos.z - z).length()
	if dp < 8.0 and not _player_invuln():
		player_hp -= 60.0 * (1.0 - dp / 8.0)
	for t in npcs + cops + guards + vips:
		var d: float = Vector2(t.pos.x - x, t.pos.z - z).length()
		if d < 8.0:
			t.hp -= 80.0 * (1.0 - d / 8.0)


func _ang_diff(a: float, b: float) -> float:
	var d := a - b
	while d > PI:
		d -= TAU
	while d < -PI:
		d += TAU
	return d


# =====================================================================
# NPCs
# =====================================================================
func _spawn_npc() -> void:
	for tries in 20:
		var x := (randf() - 0.5) * CityWorld.WORLD * 0.9
		var z := (randf() - 0.5) * CityWorld.WORLD * 0.85
		if world.collides_at(x, z, 1.0):
			continue
		var node := Human.build(NPC_SKINS.pick_random(), NPC_SHIRTS.pick_random(),
			NPC_PANTS.pick_random(), NPC_HAIR.pick_random(), -1, randf() < 0.5)
		node.position = Vector3(x, 0, z)
		add_child(node)
		npcs.append({
			"node": node, "pos": Vector3(x, 0, z), "yaw": randf() * TAU,
			"hp": 35.0, "max_hp": 35.0, "walk_timer": 0.0,
			"walk_phase": randf() * TAU, "cash": 5 + (randi() % 30),
		})
		return


func _update_npcs(dt: float) -> void:
	for n in npcs:
		if n.hp <= 0.0:
			continue
		n.walk_timer -= dt
		if n.walk_timer <= 0.0:
			n.walk_timer = 1.0 + randf() * 3.0
			n.yaw = randf() * TAU
		if _now - last_fire_at < 4.0:
			if n.pos.distance_to(player_pos) < 30.0:
				n.yaw = atan2(n.pos.x - player_pos.x, n.pos.z - player_pos.z)
		var nx: float = n.pos.x + sin(n.yaw) * 2.5 * dt
		var nz: float = n.pos.z + cos(n.yaw) * 2.5 * dt
		if not world.collides_at(nx, n.pos.z, 0.4):
			n.pos.x = nx
		else:
			n.yaw += PI
		if not world.collides_at(n.pos.x, nz, 0.4):
			n.pos.z = nz
		else:
			n.yaw += PI
		n.node.position = n.pos
		n.node.rotation.y = n.yaw
		n.walk_phase += dt * 6.0
		Human.animate(n.node, n.walk_phase, true, 0.55, 0.33)
	var keep: Array = []
	for n in npcs:
		if n.hp <= 0.0:
			_spawn_blood(n.pos.x, 1.0, n.pos.z, 16)
			_spawn_pickup(n.pos.x, n.pos.z, n.cash)
			_raise_wanted(2.0)
			n.node.queue_free()
			continue
		if n.pos.distance_to(player_pos) > 200.0:
			n.node.queue_free()
			continue
		keep.append(n)
	npcs = keep
	var guard := 0
	while npcs.size() < 40 and guard < 80:
		_spawn_npc()
		guard += 1


# =====================================================================
# Police & wanted
# =====================================================================
func _spawn_cop(near: Vector3, swat := false) -> void:
	for tries in 20:
		var ang := randf() * TAU
		var dist := (16.0 if swat else 60.0) + randf() * 36.0
		var x := near.x + cos(ang) * dist
		var z := near.z + sin(ang) * dist
		if world.collides_at(x, z, 1.0):
			continue
		var node: Node3D
		var hp := 80.0
		if swat:
			node = Human.build(0x3a3a42, 0x14161c, 0x0e0f14, 0x0a0a0a, 0x14161c)
			hp = 180.0
		else:
			node = Human.build(0xf4c28a, 0x232f44, 0x14192a, 0x2a1a08, 0x14192a)
		node.position = Vector3(x, 0, z)
		add_child(node)
		cops.append({
			"node": node, "pos": Vector3(x, 0, z), "yaw": 0.0,
			"hp": hp, "max_hp": hp, "last_shot": 0.0, "walk_phase": randf() * TAU,
			"swat": swat,
		})
		return


func _update_cops(dt: float) -> void:
	var target: Vector3 = in_car.pos if in_car != null else player_pos
	for c in cops:
		if c.hp <= 0.0:
			continue
		var dx: float = target.x - c.pos.x
		var dz: float = target.z - c.pos.z
		var d := sqrt(dx * dx + dz * dz)
		c.yaw = atan2(dx, dz)
		var cspd := 6.6 if c.get("swat", false) else 5.0
		if d > 7.0:
			var nx: float = c.pos.x + sin(c.yaw) * cspd * dt
			var nz: float = c.pos.z + cos(c.yaw) * cspd * dt
			if not world.collides_at(nx, c.pos.z, 0.4):
				c.pos.x = nx
			if not world.collides_at(c.pos.x, nz, 0.4):
				c.pos.z = nz
		c.node.position = c.pos
		c.node.rotation.y = c.yaw
		c.walk_phase += dt * 7.0
		Human.animate(c.node, c.walk_phase, d > 7.0, 0.6, 0.36)
		var fire_gap := 0.45 if c.get("swat", false) else 0.7
		if d < 60.0 and _now - c.last_shot > fire_gap:
			c.last_shot = _now
			var from := Vector3(c.pos.x, 1.4, c.pos.z)
			var dir := (Vector3(target.x, 1.2, target.z) - from).normalized()
			dir.x += (randf() - 0.5) * 0.05
			dir.z += (randf() - 0.5) * 0.05
			_spawn_bullet(from, dir.normalized(), WeaponDB.LIST[2], "cop")
			AudioFX.shoot()
			if randf() < 0.3:
				AudioFX.siren()
	var keep: Array = []
	for c in cops:
		if c.hp <= 0.0:
			_spawn_blood(c.pos.x, 1.0, c.pos.z, 20)
			_spawn_pickup(c.pos.x, c.pos.z, 60)
			c.node.queue_free()
		else:
			keep.append(c)
	cops = keep


func _update_wanted(dt: float) -> void:
	# Once the city is owned the police permanently stand down.
	if city_owned:
		GameState.wanted = 0.0
		if not cops.is_empty():
			for c in cops:
				c.node.queue_free()
			cops.clear()
		_clear_police_extras()
		return
	if GameState.wanted >= 1.0:
		cop_timer -= dt
		if cop_timer <= 0.0:
			cop_timer = max(4.0, 10.0 - GameState.wanted * 1.4)
			var n: int = max(1, int(GameState.wanted))
			for i in n:
				_spawn_cop(player_pos, GameState.wanted >= 3.0)
	# SWAT vans roll in at 3+ stars, a hunting chopper joins at 4+.
	if GameState.wanted >= 3.0:
		swat_timer -= dt
		if swat_timer <= 0.0:
			swat_timer = 17.0
			_spawn_swat_van()
	if GameState.wanted >= 4.0 and police_heli == null:
		_spawn_police_heli()
	wanted_decay += dt
	if wanted_decay > 4.0 and GameState.wanted > 0.0:
		GameState.wanted = max(0.0, GameState.wanted - dt * 0.18)
		if GameState.wanted == 0.0:
			_show_objective("You lost the cops.")
			for c in cops:
				c.node.queue_free()
			cops.clear()
			_clear_police_extras()
	var giveup := 90.0 if GameState.wanted < 2.0 else 180.0
	var keep: Array = []
	for c in cops:
		if c.pos.distance_to(player_pos) > giveup:
			c.node.queue_free()
		else:
			keep.append(c)
	cops = keep


## Free the chopper and any SWAT vans — called when the heat clears.
func _clear_police_extras() -> void:
	if police_heli != null:
		if is_instance_valid(police_heli.node):
			police_heli.node.queue_free()
		police_heli = null
	for vn in _swat_vans:
		if is_instance_valid(vn):
			vn.queue_free()
	_swat_vans.clear()


## Drop a SWAT van on open ground near the player and deploy a team.
func _spawn_swat_van() -> void:
	var spot := Vector3.INF
	for tries in 24:
		var a := randf() * TAU
		var d := 42.0 + randf() * 30.0
		var x := player_pos.x + cos(a) * d
		var z := player_pos.z + sin(a) * d
		if not world.collides_at(x, z, 2.6):
			spot = Vector3(x, 0, z)
			break
	if spot.x > 1e8:
		return
	var van := _build_swat_van()
	van.position = spot
	van.rotation.y = randf() * TAU
	add_child(van)
	_swat_vans.append(van)
	for i in 3:
		_spawn_cop(spot, true)
	while _swat_vans.size() > 4:
		var old = _swat_vans.pop_front()
		if is_instance_valid(old):
			old.queue_free()


func _build_swat_van() -> Node3D:
	var g := Node3D.new()
	var body_m := Build.mat(Build.hex(0x20242c), 0.7, 0.2)
	var dark := Build.mat(Build.hex(0x0e0f12), 0.6)
	var tire_m := Build.mat(Build.hex(0x0a0a0a), 0.95)
	var blue := Build.emissive(Build.hex(0x12203a), Color("4f7fff"), 2.0)
	var red := Build.emissive(Build.hex(0x3a1212), Color("ff4f4f"), 2.0)
	var body := Build.box(2.5, 2.4, 6.0, body_m)
	body.position.y = 1.7
	g.add_child(body)
	var cab := Build.box(2.4, 1.4, 1.8, body_m)
	cab.position = Vector3(0, 1.4, 3.0)
	g.add_child(cab)
	var bull := Build.box(2.7, 0.7, 0.6, dark)
	bull.position = Vector3(0, 0.85, 4.15)
	g.add_child(bull)
	for sx in [-1.0, 1.0]:
		for sz in [-1.7, 1.7]:
			var tire := Build.cyl(0.6, 0.6, 0.5, 12, tire_m)
			tire.rotation.z = PI / 2.0
			tire.position = Vector3(sx * 1.25, 0.6, sz)
			g.add_child(tire)
	var lb := Build.box(0.5, 0.3, 0.5, blue)
	lb.position = Vector3(-0.55, 3.05, 0.5)
	g.add_child(lb)
	var lr := Build.box(0.5, 0.3, 0.5, red)
	lr.position = Vector3(0.55, 3.05, 0.5)
	g.add_child(lr)
	return g


func _spawn_police_heli() -> void:
	var node := _build_police_heli()
	var px := player_pos.x + 64.0
	var pz := player_pos.z + 64.0
	node.position = Vector3(px, 62.0, pz)
	add_child(node)
	police_heli = {
		"node": node, "rotor": node.get_meta("rotor"),
		"pos": Vector3(px, 62.0, pz), "yaw": 0.0, "last_shot": 0.0,
	}
	_show_objective("Police chopper inbound — take cover!", 4.0)


func _build_police_heli() -> Node3D:
	var g := Node3D.new()
	var body_m := Build.mat(Build.hex(0x1c2330), 0.5, 0.3)
	var dark := Build.mat(Build.hex(0x0e0f14), 0.6)
	var glass := Build.mat(Build.hex(0x141d28), 0.1, 0.4)
	var body := Build.box(2.2, 1.9, 4.4, body_m)
	g.add_child(body)
	var nose := Build.box(1.8, 1.3, 1.4, glass)
	nose.position = Vector3(0, -0.1, 2.6)
	g.add_child(nose)
	var boom := Build.box(0.5, 0.5, 4.0, body_m)
	boom.position = Vector3(0, 0.4, -3.6)
	g.add_child(boom)
	var fin := Build.box(0.18, 1.4, 1.0, body_m)
	fin.position = Vector3(0, 1.05, -5.3)
	g.add_child(fin)
	for sx in [-1.0, 1.0]:
		var skid := Build.box(0.16, 0.16, 3.4, dark)
		skid.position = Vector3(sx * 1.0, -1.3, 0.2)
		g.add_child(skid)
	var mast := Build.box(0.3, 0.5, 0.3, dark)
	mast.position = Vector3(0, 1.2, 0)
	g.add_child(mast)
	var rotor := Node3D.new()
	rotor.position = Vector3(0, 1.5, 0)
	for ri in 2:
		var blade := Build.box(9.0, 0.1, 0.5, dark)
		blade.rotation.y = ri * PI / 2.0
		rotor.add_child(blade)
	g.add_child(rotor)
	g.set_meta("rotor", rotor)
	return g


## The hunting chopper — tracks the player from above and strafes them.
func _update_police_heli(dt: float) -> void:
	if police_heli == null:
		return
	if GameState.wanted < 3.5 or city_owned:
		_clear_police_extras()
		return
	var h: Dictionary = police_heli
	var target: Vector3 = in_car.pos if in_car != null else player_pos
	var to := Vector2(target.x - h.pos.x, target.z - h.pos.z)
	var dist := to.length()
	if dist > 16.0:
		var step := to.normalized() * 30.0 * dt
		h.pos.x += step.x
		h.pos.z += step.y
	h.pos.y = lerpf(h.pos.y, target.y + 36.0, dt * 0.8)
	h.yaw = atan2(target.x - h.pos.x, target.z - h.pos.z)
	h.node.position = h.pos
	h.node.rotation.y = h.yaw
	h.rotor.rotation.y += dt * 34.0
	if dist < 95.0 and _now - h.last_shot > 1.0:
		h.last_shot = _now
		var from: Vector3 = h.pos
		var dir := (Vector3(target.x, target.y + 1.2, target.z) - from).normalized()
		dir.x += (randf() - 0.5) * 0.06
		dir.z += (randf() - 0.5) * 0.06
		_spawn_bullet(from, dir.normalized(), WeaponDB.LIST[2], "cop")
		AudioFX.shoot()


func _raise_wanted(amt: float) -> void:
	if city_owned:
		return                                # the city is yours — no heat
	if GameState.wanted == 0.0:
		cop_timer = 5.0
	wanted_decay = 0.0
	GameState.wanted = min(5.0, GameState.wanted + amt * 0.15)


# =====================================================================
# Rich VIPs & their bodyguards
# =====================================================================
func _find_open_spot() -> Vector2:
	for tries in 60:
		var x := (randf() - 0.5) * CityWorld.WORLD * 0.8
		var z := (randf() - 0.5) * CityWorld.WORLD * 0.8
		if world._in_airport_zone(x, z):
			continue
		if not world.collides_at(x, z, 1.5):
			return Vector2(x, z)
	return Vector2.ZERO


func _spawn_vip_groups(n: int) -> void:
	for i in n:
		var spot := _find_open_spot()
		var vnode := Human.build(0xf0caa0, 0xd8d2c0, 0x2b2b32, NPC_HAIR.pick_random())
		vnode.scale = Vector3(1.07, 1.07, 1.07)
		vnode.position = Vector3(spot.x, 0, spot.y)
		add_child(vnode)
		# Rich, but not absurdly so — payouts come in four fixed tiers.
		var fortune: int = [10_000, 50_000, 100_000, 1_000_000].pick_random()
		var vip := {
			"node": vnode, "pos": Vector3(spot.x, 0, spot.y), "yaw": randf() * TAU,
			"hp": 70.0, "max_hp": 70.0, "cash": fortune,
			"walk_timer": 0.0, "walk_phase": randf() * TAU, "aggro": false, "guards": [],
		}
		vips.append(vip)
		for gi in 3:
			var ga := float(gi) / 3.0 * TAU
			var off := Vector2(cos(ga) * 4.0, sin(ga) * 4.0)
			var gx := spot.x + off.x
			var gz := spot.y + off.y
			var gnode := Human.build(0xd9a878, 0x202024, 0x18181c, 0x161616)
			gnode.position = Vector3(gx, 0, gz)
			add_child(gnode)
			# Give the bodyguard a visible pistol in hand.
			var glimbs: Dictionary = gnode.get_meta("limbs")
			var gholder := Node3D.new()
			gholder.position = Vector3(0.0, -0.86, 0.18)
			glimbs.armR.add_child(gholder)
			gholder.add_child(_weapon_model(2))
			var guard := {
				"node": gnode, "pos": Vector3(gx, 0, gz), "yaw": 0.0,
				"hp": 95.0, "max_hp": 95.0, "walk_phase": randf() * TAU,
				"last_shot": 0.0, "aggro": false, "vip": vip, "offset": off,
			}
			guards.append(guard)
			vip.guards.append(guard)


func _update_vips(dt: float) -> void:
	var keep: Array = []
	for v in vips:
		if v.hp <= 0.0:
			if v.get("is_president", false):
				_kill_president(v)
				continue
			_spawn_blood(v.pos.x, 1.2, v.pos.z, 22)
			_spawn_pickup(v.pos.x, v.pos.z, v.cash)
			_raise_wanted(3.0)
			_show_objective("VIP down  +$%d" % v.cash, 3.5)
			for g in v.guards:
				g.aggro = true
				g.vip = null
			v.node.queue_free()
			continue
		if v.get("is_president", false):
			keep.append(v)
			continue                          # the motorcade system drives the President
		if v.hp < v.max_hp:
			v.aggro = true
		var spd := 1.7
		if v.aggro:
			v.yaw = atan2(v.pos.x - player_pos.x, v.pos.z - player_pos.z)
			spd = 5.0
		else:
			v.walk_timer -= dt
			if v.walk_timer <= 0.0:
				v.walk_timer = 2.0 + randf() * 3.0
				v.yaw = randf() * TAU
		var nx: float = v.pos.x + sin(v.yaw) * spd * dt
		var nz: float = v.pos.z + cos(v.yaw) * spd * dt
		if not world.collides_at(nx, v.pos.z, 0.4):
			v.pos.x = nx
		else:
			v.yaw += PI
		if not world.collides_at(v.pos.x, nz, 0.4):
			v.pos.z = nz
		else:
			v.yaw += PI
		v.node.position = v.pos
		v.node.rotation.y = v.yaw
		v.walk_phase += dt * (7.5 if v.aggro else 4.0)
		Human.animate(v.node, v.walk_phase, true, 0.5, 0.3)
		keep.append(v)
	vips = keep

	# VIPs are unlimited — once one is robbed, another moves into the city.
	if vips.size() < VIP_TARGET:
		vip_spawn_timer -= dt
		if vip_spawn_timer <= 0.0:
			_spawn_vip_groups(1)
			vip_spawn_timer = 5.0
	else:
		vip_spawn_timer = 5.0


func _update_guards(dt: float) -> void:
	var target: Vector3 = in_car.pos if in_car != null else player_pos
	var keep: Array = []
	for g in guards:
		if g.hp <= 0.0:
			_spawn_blood(g.pos.x, 1.0, g.pos.z, 16)
			_spawn_pickup(g.pos.x, g.pos.z, 120)
			_raise_wanted(0.6)
			g.node.queue_free()
			continue
		if g.get("motorcade", false):
			keep.append(g)
			continue                          # the motorcade system drives its guards
		if g.hp < g.max_hp:
			g.aggro = true
			if g.vip != null:
				g.vip.aggro = true
		if g.vip != null and g.vip.aggro:
			g.aggro = true
		# Give up the chase once the player gets far enough away.
		if g.aggro and Vector2(target.x - g.pos.x, target.z - g.pos.z).length() > 160.0:
			if g.vip == null:
				g.node.queue_free()
				continue
			g.aggro = false
			g.hp = g.max_hp
		if g.aggro:
			var dx: float = target.x - g.pos.x
			var dz: float = target.z - g.pos.z
			var d := sqrt(dx * dx + dz * dz)
			g.yaw = atan2(dx, dz)
			if d > 6.0:
				var nx: float = g.pos.x + sin(g.yaw) * 5.5 * dt
				var nz: float = g.pos.z + cos(g.yaw) * 5.5 * dt
				if not world.collides_at(nx, g.pos.z, 0.4):
					g.pos.x = nx
				if not world.collides_at(g.pos.x, nz, 0.4):
					g.pos.z = nz
			if d < 55.0 and _now - g.last_shot > 0.85:
				g.last_shot = _now
				var from := Vector3(g.pos.x, 1.4, g.pos.z)
				var dir := (Vector3(target.x, 1.2, target.z) - from).normalized()
				dir.x += (randf() - 0.5) * 0.06
				dir.z += (randf() - 0.5) * 0.06
				_spawn_bullet(from, dir.normalized(), WeaponDB.LIST[2], "cop")
				AudioFX.shoot()
			g.walk_phase += dt * 7.0
			Human.animate(g.node, g.walk_phase, d > 6.0, 0.6, 0.36)
		else:
			# Escort: hold a fixed offset around the VIP.
			var dest: Vector3 = g.vip.pos + Vector3(g.offset.x, 0, g.offset.y)
			var dx: float = dest.x - g.pos.x
			var dz: float = dest.z - g.pos.z
			var d := sqrt(dx * dx + dz * dz)
			var moving := d > 0.7
			if moving:
				g.yaw = atan2(dx, dz)
				var nx: float = g.pos.x + sin(g.yaw) * 3.2 * dt
				var nz: float = g.pos.z + cos(g.yaw) * 3.2 * dt
				if not world.collides_at(nx, g.pos.z, 0.4):
					g.pos.x = nx
				if not world.collides_at(g.pos.x, nz, 0.4):
					g.pos.z = nz
			g.walk_phase += dt * 6.0
			Human.animate(g.node, g.walk_phase, moving, 0.5, 0.3)
		g.node.position = g.pos
		g.node.rotation.y = g.yaw
		keep.append(g)
	guards = keep


# =====================================================================
# Particles & pickups
# =====================================================================
func _spawn_particle(x: float, y: float, z: float, color: int, life: float,
		vx: float, vy: float, vz: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Build.hex(color)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var node := Build.box(0.15, 0.15, 0.15, mat)
	node.position = Vector3(x, y, z)
	add_child(node)
	particles.append({"node": node, "pos": Vector3(x, y, z), "vel": Vector3(vx, vy, vz),
		"life": life, "mat": mat})


func _spawn_blood(x: float, y: float, z: float, n: int) -> void:
	for i in n:
		_spawn_particle(x, y, z, 0xc0223a, 0.6,
			(randf() - 0.5) * 3.0, randf() * 2.0, (randf() - 0.5) * 3.0)


func _spawn_sparks(x: float, y: float, z: float, n: int) -> void:
	for i in n:
		_spawn_particle(x, y, z, 0xf9e94e, 0.3,
			(randf() - 0.5) * 4.0, randf() * 3.0, (randf() - 0.5) * 4.0)


func _spawn_fire(x: float, y: float, z: float, n: int) -> void:
	for i in n:
		var col: int = [0xff5733, 0xffaa33, 0x444444].pick_random()
		_spawn_particle(x, y + 1.0, z, col, 0.8 + randf() * 0.5,
			(randf() - 0.5) * 2.0, 3.0 + randf() * 2.0, (randf() - 0.5) * 2.0)


func _update_particles(dt: float) -> void:
	var keep: Array = []
	for pa in particles:
		pa.pos += pa.vel * dt
		pa.vel.y -= 9.0 * dt
		pa.life -= dt
		pa.mat.albedo_color.a = clamp(pa.life * 2.0, 0.0, 1.0)
		if pa.life <= 0.0:
			pa.node.queue_free()
		else:
			pa.node.position = pa.pos
			keep.append(pa)
	particles = keep


func _spawn_pickup(x: float, z: float, amount: int) -> void:
	var node := Build.box(0.5, 0.5, 0.5, _pickup_mat)
	node.position = Vector3(x, 0.6, z)
	add_child(node)
	pickups.append({"node": node, "pos": Vector3(x, 0.6, z), "amount": amount, "taken": false})


func _update_pickups(dt: float) -> void:
	var keep: Array = []
	for k in pickups:
		k.node.rotation.y += dt * 3.0
		k.node.position.y = 0.6 + sin(_now * 5.0) * 0.1
		if Vector2(k.pos.x - player_pos.x, k.pos.z - player_pos.z).length() < 1.5:
			GameState.money += k.amount
			AudioFX.coin()
			k.taken = true
		if k.taken:
			k.node.queue_free()
		else:
			keep.append(k)
	pickups = keep


# =====================================================================
# Vehicle construction
# =====================================================================
# ---------------- AI race cars ----------------
## Spawn the field of AI racers that loop the F1 circuit on the racing line.
func _spawn_racers() -> void:
	for r in racers:
		r.node.queue_free()
	racers.clear()
	if world.track == null:
		return
	var n: int = world.track.baked.size()
	var cols := [0x3a6ea5, 0x46a35a, 0xd9a441, 0x8e44ad, 0x2aa39a]
	for i in cols.size():
		var node := CarMesh.build(cols[i], "f1")
		add_child(node)
		racers.append({
			"node": node,
			"fi": float(((i + 1) * 7) % n),
			"speed": 40.0, "lap": 0, "prog": 0.0,
			"offset": (float(i) - 2.0) * 2.7,
			"skill": 88.0 + i * 4.0,
		})


## Rail-follow the AI racers along the baked centreline and rank the player.
func _update_racers(dt: float) -> void:
	var t: Track = world.track
	if t == null or racers.is_empty():
		return
	var n: int = t.baked.size()
	# The player's monotonic race progress — distance covered since the grid,
	# measured in centreline steps. Robust across the start/finish line.
	if RaceManager.state == "racing" and in_car != null:
		_player_prog += maxf(0.0, in_car.speed) * dt / Track.SAMPLE
	var rank := 1
	for r in racers:
		# Frozen on the grid during the countdown; racing otherwise.
		if RaceManager.state != "countdown":
			var ahead: int = int(r.fi + 7.0) % n
			var corner: float = t._corner_amount(ahead)
			var target: float = lerpf(r.skill, 20.0, clampf(corner, 0.0, 1.0))
			r.speed = move_toward(r.speed, target, 26.0 * dt)
			r.fi += r.speed * dt / Track.SAMPLE
			if r.fi >= n:
				r.fi -= n
				r.lap += 1
			if RaceManager.state == "racing":
				r.prog += r.speed * dt / Track.SAMPLE
		var i0: int = int(r.fi) % n
		var i1: int = (i0 + 1) % n
		var frac: float = r.fi - floor(r.fi)
		var base: Vector3 = t.baked[i0].lerp(t.baked[i1], frac)
		var rt: Vector3 = t.rights[i0]
		r.node.position = Vector3(base.x + rt.x * r.offset, 0.0,
			base.z + rt.z * r.offset)
		r.node.rotation.y = atan2(t.forwards[i0].x, t.forwards[i0].z)
		if r.prog > _player_prog:
			rank += 1
	race_rank = rank
	race_total = racers.size() + 1


func _make_vehicle(x: float, z: float, color: int, style := "sedan") -> Dictionary:
	var g := CarMesh.build(color, style, false, head_mat, tail_mat)
	g.position = Vector3(x, 0, z)
	add_child(g)
	return {
		"node": g, "pos": Vector3(x, 0, z), "yaw": randf() * TAU, "speed": 0.0,
		"max_speed": 28.0, "hp": 100.0, "max_hp": 100.0, "style": style,
		"burning": false, "burn_timer": 0.0, "is_plane": false, "propeller": null,
	}


# ======================================================================
# Space programme — rocket, Moon trip, re-entry
# ======================================================================
## A low-poly rocket. The booster is its own node so it can detach in flight.
## `pos` is the upper stage's base; the booster hangs ROCKET_BOOSTER_H below.
func _make_rocket(x: float, z: float) -> Dictionary:
	var white := Build.mat(Build.hex(0xeef0f2), 0.4, 0.2)
	var dark := Build.mat(Build.hex(0x2a2d33), 0.5, 0.3)
	var accent := Build.mat(Build.hex(0xc23a3a), 0.4)
	var metal := Build.mat(Build.hex(0x9a9ca0), 0.3, 0.7)
	var glass := Build.mat(Build.hex(0x141d28), 0.1, 0.4)
	var flame := Build.emissive(Build.hex(0xffb030), Build.hex(0xff8020), 3.0)

	# Booster (lower stage).
	var booster := Node3D.new()
	var b_body := Build.cyl(2.4, 2.6, ROCKET_BOOSTER_H, 16, white)
	b_body.position = Vector3(0, ROCKET_BOOSTER_H / 2.0, 0)
	booster.add_child(b_body)
	var b_stripe := Build.cyl(2.64, 2.64, 2.0, 16, accent)
	b_stripe.position = Vector3(0, 3.2, 0)
	booster.add_child(b_stripe)
	for fi in 4:
		var fa := fi * PI / 2.0
		var fin := Build.box(0.4, 4.6, 3.0, dark)
		fin.position = Vector3(cos(fa) * 2.7, 2.4, sin(fa) * 2.7)
		fin.rotation.y = fa
		booster.add_child(fin)
	var bell := Build.cyl(1.5, 2.3, 2.6, 14, metal)
	bell.position = Vector3(0, -0.9, 0)
	booster.add_child(bell)
	add_child(booster)

	# Upper stage — the vehicle node. Origin at its base.
	var g := Node3D.new()
	var u_body := Build.cyl(2.0, 2.4, 10.0, 16, white)
	u_body.position = Vector3(0, 5.0, 0)
	g.add_child(u_body)
	var nose := Build.cyl(0.16, 2.0, 4.6, 16, white)
	nose.position = Vector3(0, 12.3, 0)
	g.add_child(nose)
	var u_stripe := Build.cyl(2.44, 2.44, 1.4, 16, accent)
	u_stripe.position = Vector3(0, 8.8, 0)
	g.add_child(u_stripe)
	for wi in 3:
		var wa := wi * TAU / 3.0
		var win := Build.box(0.2, 0.7, 0.7, glass)
		win.position = Vector3(cos(wa) * 2.06, 9.6, sin(wa) * 2.06)
		win.rotation.y = wa
		g.add_child(win)
	var plume := Build.sphere(1.7, flame)
	plume.position = Vector3(0, -1.2, 0)
	plume.visible = false
	g.add_child(plume)
	add_child(g)

	var base_y := ROCKET_BASE_Y + ROCKET_BOOSTER_H
	g.position = Vector3(x, base_y, z)
	booster.position = Vector3(x, ROCKET_BASE_Y, z)

	return {
		"node": g, "booster": booster, "plume": plume,
		"pos": Vector3(x, base_y, z), "yaw": 0.0, "speed": 0.0, "throttle": 0.0,
		"tilt": 0.0, "max_speed": 135.0, "max_alt": 9000.0,
		"hp": 9999.0, "max_hp": 9999.0, "burning": false, "burn_timer": 0.0,
		"is_plane": true, "is_rocket": true, "on_ground": true, "separated": false,
		"radius": 3.2, "cam_dist": 28.0,
	}


func _spawn_rocket() -> void:
	vehicles.append(_make_rocket(CityWorld.LAUNCH.x, CityWorld.LAUNCH.z))


## An open-frame moon buggy, parked on the lunar surface near the lander.
func _make_moon_buggy(x: float, z: float) -> Dictionary:
	var g := Node3D.new()
	var frame_m := Build.mat(Build.hex(0xcdd0d4), 0.5, 0.5)
	var dark := Build.mat(Build.hex(0x2a2d33), 0.6)
	var gold := Build.mat(Build.hex(0xd9b24a), 0.4, 0.6)
	var floor_p := Build.box(2.2, 0.2, 3.4, gold)
	floor_p.position.y = 0.72
	g.add_child(floor_p)
	for fz in [-1.3, 1.3]:
		var bar := Build.box(2.0, 0.12, 0.12, frame_m)
		bar.position = Vector3(0, 1.5, fz)
		g.add_child(bar)
	for fx in [-1.0, 1.0]:
		var side := Build.box(0.12, 0.12, 2.8, frame_m)
		side.position = Vector3(fx, 1.5, 0.0)
		g.add_child(side)
		for fz2 in [-1.3, 1.3]:
			var post := Build.box(0.12, 0.85, 0.12, frame_m)
			post.position = Vector3(fx, 1.1, fz2)
			g.add_child(post)
	var seat := Build.box(1.0, 0.5, 0.9, dark)
	seat.position = Vector3(0, 1.05, -0.2)
	g.add_child(seat)
	var dish := Build.cyl(0.2, 1.0, 0.35, 10, frame_m)
	dish.rotation.x = -0.8
	dish.position = Vector3(0.7, 1.95, -1.2)
	g.add_child(dish)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var tire := Build.cyl(0.6, 0.6, 0.42, 12, dark)
			tire.rotation.z = PI / 2.0
			tire.position = Vector3(sx * 1.2, 0.6, sz * 1.25)
			g.add_child(tire)
	g.position = Vector3(x, CityWorld.MOON_Y, z)
	add_child(g)
	return {
		"node": g, "pos": Vector3(x, CityWorld.MOON_Y, z), "yaw": 0.0,
		"speed": 0.0, "max_speed": 24.0, "hp": 200.0, "max_hp": 200.0,
		"style": "buggy", "moon": true, "is_plane": false,
		"burning": false, "burn_timer": 0.0,
	}


func _spawn_moon_buggy() -> void:
	vehicles.append(_make_moon_buggy(CityWorld.MOON_PAD.x + 16.0,
		CityWorld.MOON_PAD.z + 9.0))


## Drive the buggy across the open lunar surface — flat at MOON_Y, low-gravity
## float over the bumps, no city collision.
func _update_moon_buggy(v: Dictionary, dt: float) -> void:
	var accel := (1.0 if _key(KEY_W) else 0.0) - (1.0 if _key(KEY_S) else 0.0)
	var turn := (1.0 if _key(KEY_A) else 0.0) - (1.0 if _key(KEY_D) else 0.0)
	v.speed += accel * 20.0 * dt
	v.speed *= 1.0 - dt * 0.9
	v.speed = clampf(v.speed, -9.0, v.max_speed)
	if absf(v.speed) > 0.4:
		var sgn := 1.0 if v.speed > 0.0 else -1.0
		v.yaw += turn * 1.4 * dt * sgn * minf(1.0, absf(v.speed) / 6.0)
	v.pos.x += sin(v.yaw) * v.speed * dt
	v.pos.z += cos(v.yaw) * v.speed * dt
	v.pos.y = CityWorld.MOON_Y
	var bounce: float = absf(sin(_now * 5.0)) * minf(absf(v.speed) * 0.04, 0.4)
	v.node.position = Vector3(v.pos.x, CityWorld.MOON_Y + bounce, v.pos.z)
	v.node.rotation.y = v.yaw
	player_pos = v.pos


## The Y the rocket's base rests on, by trip leg. The booster only adds height
## while it is still attached (the launch); once dropped, the upper stage sits
## on its own base.
func _rocket_floor() -> float:
	match space_state:
		"moon_descent", "moon_landed", "moon", "moon_ascent":
			return CityWorld.MOON_Y
		"splashdown":
			return 1.0
		"reentry":
			return -100000.0
		_:
			return ROCKET_BASE_Y + ROCKET_BOOSTER_H


## True while the dark space sky is showing (day/night tinting is suspended).
func _in_space_sky() -> bool:
	return space_state in ["space_climb", "space", "moon_descent", "moon_landed",
		"moon", "moon_ascent"]


func _set_space_sky(on: bool) -> void:
	if on:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.015, 0.02, 0.045)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.55, 0.55, 0.62)
		env.ambient_light_energy = 0.55
		env.fog_enabled = false
	else:
		env.background_mode = Environment.BG_SKY
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.fog_enabled = true


func _update_rocket(v: Dictionary, dt: float) -> void:
	var scripted: bool = space_state == "moon_descent" or space_state == "reentry"
	var thrust := 1.0 if (_key(KEY_W) or _key(KEY_UP)) else 0.0
	var brake := 1.0 if (_key(KEY_S) or _key(KEY_DOWN)) else 0.0
	var turn := (1.0 if _key(KEY_A) else 0.0) - (1.0 if _key(KEY_D) else 0.0)

	if scripted:
		var desc := -26.0 if space_state == "moon_descent" else -82.0
		v.speed = move_toward(v.speed, desc, 70.0 * dt)
	else:
		v.throttle = move_toward(v.throttle, thrust, 1.3 * dt)
		var target: float = v.throttle * v.max_speed - brake * 45.0
		v.speed = move_toward(v.speed, target, v.max_speed * 0.5 * dt)
	v.plume.visible = v.speed > 2.0 or v.throttle > 0.12
	if v.throttle > 0.25 and randf() < 0.16:
		AudioFX.rumble()

	v.pos.y += v.speed * dt
	var floor_y := _rocket_floor()
	if v.pos.y <= floor_y:
		v.pos.y = floor_y
		v.speed = maxf(v.speed, 0.0)
		v.on_ground = true
	else:
		v.on_ground = false

	if not scripted:
		v.yaw += turn * 0.55 * dt
		v.tilt = lerpf(v.tilt, turn * 0.13, dt * 3.0)
		if v.pos.y > floor_y + 1.0:
			v.pos.x += sin(v.yaw) * v.tilt * 26.0 * dt
			v.pos.z += cos(v.yaw) * v.tilt * 26.0 * dt
	else:
		v.tilt = lerpf(v.tilt, 0.0, dt * 2.0)

	v.node.position = v.pos
	v.node.rotation = Vector3(v.tilt, v.yaw, 0.0)
	if not v.separated:
		v.booster.position = v.pos - Vector3(0, ROCKET_BOOSTER_H, 0)
		v.booster.rotation = v.node.rotation
	player_pos = v.pos
	_space_tick(v, dt)


## The state machine that drives the whole journey off altitude triggers.
func _space_tick(v: Dictionary, dt: float) -> void:
	match space_state:
		"ascent":
			if v.pos.y > 520.0 and not v.separated:
				_separate_booster(v)
			if v.pos.y > 1500.0:
				space_state = "space_climb"
				_set_space_sky(true)
				_show_objective("ENTERING SPACE — keep climbing for the Moon.", 5.0)
		"space_climb", "space":
			space_state = "space"
			if v.pos.y > 3000.0:
				space_state = "moon_descent"
				v.pos = Vector3(CityWorld.MOON_PAD.x,
					CityWorld.MOON_Y + 280.0, CityWorld.MOON_PAD.z)
				v.speed = -12.0
				v.yaw = 0.0
				_show_objective("APPROACHING THE MOON", 4.0)
		"moon_descent":
			if v.pos.y <= CityWorld.MOON_Y + 0.6:
				space_state = "moon_landed"
				_show_objective("TOUCHDOWN ON THE MOON — press F to step out.", 9.0)
		"moon_ascent":
			if v.pos.y > CityWorld.MOON_Y + 900.0:
				space_state = "reentry"
				v.pos = Vector3(40.0, 2400.0, CityWorld.WORLD_HALF + 220.0)
				v.speed = -45.0
				v.yaw = 0.0
				_set_space_sky(false)
				_show_objective("RE-ENTRY — the heat shield is glowing.", 5.0)
		"reentry":
			_spawn_fire(v.pos.x + randf() * 5.0 - 2.5, v.pos.y - 7.0,
				v.pos.z + randf() * 5.0 - 2.5, 3)
			if v.pos.y <= 34.0:
				space_state = "splashdown"
				_show_objective("SPLASHDOWN — press F for the recovery crew.", 10.0)


func _separate_booster(v: Dictionary) -> void:
	v.separated = true
	_falling_boosters.append({
		"node": v.booster, "vy": -3.0,
		"spin": Vector3(randf() - 0.5, 0.0, randf() - 0.5) * 1.2,
	})
	_show_objective("BOOSTER SEPARATION", 4.0)


func _update_falling_boosters(dt: float) -> void:
	var keep: Array = []
	for b in _falling_boosters:
		if not is_instance_valid(b.node):
			continue
		b.vy -= 18.0 * dt
		b.node.position.y += b.vy * dt
		b.node.rotation += b.spin * dt
		if b.node.position.y < -60.0:
			b.node.queue_free()
		else:
			keep.append(b)
	_falling_boosters = keep


## Step out of the rocket — only allowed on the Moon or after splashdown.
func _exit_rocket(v: Dictionary) -> void:
	match space_state:
		"ascent":
			# Still parked on the pad — let the player change their mind.
			if v.pos.y < ROCKET_BASE_Y + ROCKET_BOOSTER_H + 4.0:
				space_state = ""
				in_car = null
				cam_dist = 6.5
				player_pos = Vector3(v.pos.x + 8.0, 0, v.pos.z)
				player_node.visible = true
				_show_objective("Stepped off the rocket.")
			else:
				_show_objective("You can't leave the rocket mid-flight.", 3.0)
		"moon_landed":
			space_state = "moon"
			in_car = null
			cam_dist = 6.5
			player_pos = Vector3(v.pos.x + 7.0, CityWorld.MOON_Y, v.pos.z)
			player_node.visible = true
			_show_objective("On the Moon. Low gravity — walk around. "
				+ "Board the rocket again to fly home.", 9.0)
		"splashdown":
			in_car = null
			cam_dist = 6.5
			var dock: Vector3 = world.nearest_dock(v.pos)
			if dock.x < 1e8:
				player_pos = Vector3(dock.x, 0, dock.z)
			else:
				player_pos = Vector3(0, 0, CityWorld.WORLD_HALF - 12.0)
			player_node.visible = true
			v.node.queue_free()
			if is_instance_valid(v.booster):
				v.booster.queue_free()
			vehicles.erase(v)
			space_state = ""
			_set_space_sky(false)
			_spawn_rocket()
			_show_objective("The recovery crew brought you ashore. "
				+ "A fresh rocket waits at the pad.", 8.0)
		_:
			_show_objective("You can't leave the rocket mid-flight.", 3.0)


func _make_plane(x: float, z: float, yaw: float, scale := 1.0) -> Dictionary:
	# A low-poly airliner — nose points +Z. Fuselage, swept wings + winglets,
	# under-wing engines, a tail fin, stabilisers, window row and landing gear.
	var g := Node3D.new()
	var body_m := Build.mat(Build.hex(0xeef1f4), 0.4, 0.25)
	var accent_m := Build.mat(Build.hex(0xc23a3a), 0.4, 0.2)
	var dark_m := Build.mat(Build.hex(0x33373d), 0.35, 0.4)
	var metal_m := Build.mat(Build.hex(0x8e9298), 0.3, 0.7)
	var win_m := Build.mat(Build.hex(0x9fb6c8), 0.2, 0.5)
	var glass_m := Build.mat(Build.hex(0x141d28), 0.1, 0.4)
	glass_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_m.albedo_color.a = 0.7

	var fy := 2.3

	# Fuselage — a long round tube laid along +Z.
	var fus := Build.cyl(1.05, 1.05, 12.6, 14, body_m)
	fus.rotation.x = PI / 2.0
	fus.position = Vector3(0, fy, 0)
	g.add_child(fus)
	# Nose cone — its point faces +Z (forward).
	var nose := Build.cyl(0.14, 1.05, 3.4, 14, body_m)
	nose.rotation.x = PI / 2.0
	nose.position = Vector3(0, fy, 7.9)
	g.add_child(nose)
	# Tail cone — tapers up to a point at the back (-Z).
	var tcone := Build.cyl(0.16, 1.05, 4.2, 14, body_m)
	tcone.rotation.x = -PI / 2.0
	tcone.position = Vector3(0, fy + 0.45, -8.2)
	g.add_child(tcone)
	# Cockpit canopy near the nose.
	var cockpit := Build.box(1.45, 0.7, 2.4, glass_m)
	cockpit.position = Vector3(0, fy + 0.82, 4.7)
	g.add_child(cockpit)
	# A red cheatline stripe down each side, airliner-style.
	for sx0 in [-1.0, 1.0]:
		var stripe := Build.box(0.1, 0.42, 11.5, accent_m)
		stripe.position = Vector3(sx0 * 1.04, fy + 0.18, -0.4)
		g.add_child(stripe)
	# Cabin window row.
	for wi in 11:
		var wz := 3.6 - wi * 0.78
		for sx in [-1.03, 1.03]:
			var win := Build.box(0.1, 0.3, 0.4, win_m)
			win.position = Vector3(sx, fy + 0.5, wz)
			g.add_child(win)

	# Wings — long, flat, gently swept, mounted low on the fuselage.
	for side in [-1.0, 1.0]:
		var wing := Build.box(8.8, 0.4, 3.5, body_m)
		wing.position = Vector3(side * 5.4, fy - 0.55, -0.3)
		wing.rotation.y = side * 0.2
		g.add_child(wing)
		var wl := Build.box(0.34, 1.05, 1.0, body_m)
		wl.position = Vector3(side * 9.6, fy - 0.05, -1.4)
		wl.rotation.z = side * 0.4
		g.add_child(wl)
		var eng := Build.cyl(0.64, 0.7, 3.2, 12, dark_m)
		eng.rotation.x = PI / 2.0
		eng.position = Vector3(side * 4.4, fy - 1.3, 0.5)
		g.add_child(eng)
		var intake := Build.cyl(0.66, 0.66, 0.3, 12, metal_m)
		intake.rotation.x = PI / 2.0
		intake.position = Vector3(side * 4.4, fy - 1.3, 2.15)
		g.add_child(intake)

	# Tail — one vertical fin and two horizontal stabilisers.
	var fin := Build.box(0.4, 3.9, 3.0, body_m)
	fin.position = Vector3(0, fy + 2.45, -6.7)
	g.add_child(fin)
	var fin_acc := Build.box(0.44, 3.0, 1.1, accent_m)
	fin_acc.position = Vector3(0, fy + 2.7, -7.7)
	g.add_child(fin_acc)
	for side in [-1.0, 1.0]:
		var stab := Build.box(4.6, 0.3, 1.9, body_m)
		stab.position = Vector3(side * 2.5, fy + 0.6, -7.4)
		stab.rotation.y = side * 0.16
		g.add_child(stab)

	# Tricycle landing gear.
	for gear in [Vector3(0, 0, 5.4), Vector3(-2.3, 0, -0.4), Vector3(2.3, 0, -0.4)]:
		var strut := Build.cyl(0.13, 0.13, 1.7, 6, metal_m)
		strut.position = Vector3(gear.x, fy - 1.85, gear.z)
		g.add_child(strut)
		var wheel := Build.cyl(0.42, 0.42, 0.34, 12, dark_m)
		wheel.rotation.z = PI / 2.0
		wheel.position = Vector3(gear.x, 0.42, gear.z)
		g.add_child(wheel)

	g.scale = Vector3(scale, scale, scale)
	g.position = Vector3(x, 0, z)
	g.rotation.y = yaw
	add_child(g)
	return {
		"node": g, "pos": Vector3(x, 0, z), "yaw": yaw, "pitch": 0.0, "roll": 0.0,
		"speed": 0.0, "vy": 0.0, "throttle": 0.0,
		"max_speed": 62.0, "max_alt": 240.0,
		"hp": 110.0 + 50.0 * scale, "max_hp": 110.0 + 50.0 * scale,
		"burning": false, "burn_timer": 0.0,
		"is_plane": true, "on_ground": true, "propeller": null,
		"radius": 2.6 * scale, "cam_dist": clampf(13.0 * scale, 13.0, 24.0),
	}


# =====================================================================
# Boats
# =====================================================================
## A water craft — speedboat, jetski or submarine. Nose points +Z.
func _make_boat(x: float, z: float, yaw: float, style := "boat") -> Dictionary:
	var g := Node3D.new()
	var max_speed := 26.0
	match style:
		"jetski":
			_build_jetski_mesh(g)
			max_speed = 34.0
		"submarine":
			_build_submarine_mesh(g)
			max_speed = 18.0
		_:
			_build_speedboat_mesh(g)
	g.position = Vector3(x, 0.35, z)
	g.rotation.y = yaw
	add_child(g)
	return {
		"node": g, "pos": Vector3(x, 0.35, z), "yaw": yaw, "speed": 0.0,
		"max_speed": max_speed, "hp": 150.0, "max_hp": 150.0, "style": style,
		"burning": false, "burn_timer": 0.0, "is_plane": false, "is_boat": true,
		"bob": randf() * TAU, "dive": 0.0,
	}


func _build_speedboat_mesh(g: Node3D) -> void:
	var hull_c: int = [0xe8e8e8, 0xcf3a3a, 0x2f6fb0, 0xf0c020][randi() % 4]
	var hull_m := Build.mat(Build.hex(hull_c), 0.5, 0.2)
	var deck_m := Build.mat(Build.hex(0xc9a878), 0.8)
	var trim_m := Build.mat(Build.hex(0x26262c), 0.4, 0.4)
	var glass_m := Build.mat(Build.hex(0x9fc4d8), 0.15, 0.4)
	var hull := Build.box(2.8, 1.0, 8.4, hull_m)
	hull.position.y = 0.5
	g.add_child(hull)
	var bow := Build.box(2.6, 0.95, 1.6, hull_m)
	bow.position = Vector3(0, 0.55, 4.6)
	bow.rotation.x = -0.4
	g.add_child(bow)
	var deck := Build.box(2.4, 0.12, 7.4, deck_m)
	deck.position = Vector3(0, 1.05, 0.2)
	g.add_child(deck)
	var rail := Build.box(2.95, 0.22, 8.5, trim_m)
	rail.position = Vector3(0, 1.0, 0.0)
	g.add_child(rail)
	var cabin := Build.box(2.0, 0.7, 1.8, trim_m)
	cabin.position = Vector3(0, 1.5, 1.5)
	g.add_child(cabin)
	var shield := Build.box(1.9, 0.7, 0.12, glass_m)
	shield.position = Vector3(0, 1.62, 2.4)
	shield.rotation.x = 0.5
	g.add_child(shield)
	for sz in [-1.7, -0.3]:
		var seat := Build.box(1.8, 0.4, 0.8, trim_m)
		seat.position = Vector3(0, 1.34, sz)
		g.add_child(seat)
	var motor := Build.box(0.7, 1.05, 0.7, trim_m)
	motor.position = Vector3(0, 0.95, -4.6)
	g.add_child(motor)


func _build_jetski_mesh(g: Node3D) -> void:
	var hull_c: int = [0xcf3a3a, 0x2f6fb0, 0xf0c020, 0x33aa55][randi() % 4]
	var hull_m := Build.mat(Build.hex(hull_c), 0.45, 0.3)
	var dark := Build.mat(Build.hex(0x1a1a1f), 0.5)
	var hull := Build.box(1.1, 0.6, 3.5, hull_m)
	hull.position.y = 0.55
	g.add_child(hull)
	var bow := Build.box(1.0, 0.55, 1.1, hull_m)
	bow.position = Vector3(0, 0.62, 2.0)
	bow.rotation.x = -0.42
	g.add_child(bow)
	var seat := Build.box(0.74, 0.3, 1.5, dark)
	seat.position = Vector3(0, 0.92, -0.35)
	g.add_child(seat)
	var col := Build.box(0.42, 0.62, 0.5, hull_m)
	col.position = Vector3(0, 1.12, 0.95)
	g.add_child(col)
	var bars := Build.box(0.9, 0.1, 0.12, dark)
	bars.position = Vector3(0, 1.4, 1.05)
	g.add_child(bars)


func _build_submarine_mesh(g: Node3D) -> void:
	var hull_m := Build.mat(Build.hex(0x33433a), 0.7, 0.35)
	var dark := Build.mat(Build.hex(0x1a1f1c), 0.6)
	var glass := Build.mat(Build.hex(0x9fc4d8), 0.15, 0.4)
	var hull := Build.cyl(1.3, 1.3, 10.6, 16, hull_m)
	hull.rotation.x = PI / 2.0
	hull.position.y = 0.7
	g.add_child(hull)
	var nose := Build.cyl(0.3, 1.3, 1.9, 14, hull_m)
	nose.rotation.x = PI / 2.0
	nose.position = Vector3(0, 0.7, 6.2)
	g.add_child(nose)
	var tail := Build.cyl(0.3, 1.3, 1.9, 14, hull_m)
	tail.rotation.x = -PI / 2.0
	tail.position = Vector3(0, 0.7, -6.2)
	g.add_child(tail)
	var tower := Build.box(1.0, 1.6, 2.6, hull_m)
	tower.position = Vector3(0, 2.0, 0.4)
	g.add_child(tower)
	var ports := Build.box(1.04, 0.4, 1.4, glass)
	ports.position = Vector3(0, 2.3, 0.5)
	g.add_child(ports)
	var fin := Build.box(0.18, 0.9, 1.5, dark)
	fin.position = Vector3(0, 3.0, 0.1)
	g.add_child(fin)
	var peri := Build.cyl(0.08, 0.08, 1.4, 6, dark)
	peri.position = Vector3(0, 3.5, 0.9)
	g.add_child(peri)


## Moor water craft at the docks — speedboats, a couple of jetskis, one sub.
func _spawn_boats() -> void:
	var i := 0
	for d in world.docks:
		var b: Vector3 = d.board
		var dir: Vector2 = d.dir
		var bx: float = b.x + dir.x * 3.2
		var bz: float = b.z + dir.y * 3.2
		var yaw: float = 0.0 if absf(dir.x) > absf(dir.y) else PI / 2.0
		var style := "boat"
		if i % 3 == 1:
			style = "jetski"
		elif i == 0:
			style = "submarine"
		vehicles.append(_make_boat(bx, bz, yaw, style))
		# A jetski tucked alongside every speedboat dock for variety.
		if style == "boat":
			vehicles.append(_make_boat(bx + dir.y * 4.0, bz + dir.x * 4.0,
				yaw, "jetski"))
		i += 1


func _update_boat(v: Dictionary, dt: float) -> void:
	var accel := (1.0 if _key(KEY_W) else 0.0) - (1.0 if _key(KEY_S) else 0.0)
	var turn := (1.0 if _key(KEY_A) else 0.0) - (1.0 if _key(KEY_D) else 0.0)
	# Submarines dive — Down submerges, Up surfaces.
	if v.get("style", "") == "submarine":
		var d := (1.0 if _key(KEY_DOWN) else 0.0) - (1.0 if _key(KEY_UP) else 0.0)
		v.dive = clampf(v.get("dive", 0.0) + d * 3.5 * dt, 0.0, 3.2)
	v.speed += accel * v.max_speed * 0.5 * dt
	v.speed *= 1.0 - dt * 0.7
	v.speed = clampf(v.speed, -v.max_speed * 0.4, v.max_speed)
	if absf(v.speed) > 0.6:
		var sgn := 1.0 if v.speed > 0.0 else -1.0
		v.yaw += turn * 1.1 * dt * sgn * minf(1.0, absf(v.speed) / 5.0)
	var dx: float = sin(v.yaw) * v.speed * dt
	var dz: float = cos(v.yaw) * v.speed * dt
	# Boats glide on water and bump back off the shoreline.
	if world.on_water(v.pos.x + dx, v.pos.z):
		v.pos.x += dx
	else:
		v.speed *= -0.25
	if world.on_water(v.pos.x, v.pos.z + dz):
		v.pos.z += dz
	else:
		v.speed *= -0.25
	v.bob += dt * 2.4
	v.node.position = Vector3(v.pos.x,
		0.35 - v.get("dive", 0.0) + sin(v.bob) * 0.07, v.pos.z)
	v.node.rotation.y = v.yaw
	v.node.rotation.z = sin(v.bob) * 0.045
	v.node.rotation.x = -clampf(v.speed * 0.012, -0.12, 0.12)
	if absf(v.speed) > 4.0 and randf() < 0.7:
		_spawn_particle(v.pos.x - sin(v.yaw) * 3.0, 0.3, v.pos.z - cos(v.yaw) * 3.0,
			0xcfe6ef, 0.5, (randf() - 0.5) * 1.6, 0.5, (randf() - 0.5) * 1.6)
	if absf(v.speed) > 1.0 and randf() < 0.1:
		AudioFX.engine()
	player_pos = Vector3(v.pos.x, 0.0, v.pos.z)
	if v.hp <= 0.0 and not v.burning:
		v.burning = true
		v.burn_timer = 2.0
	if v.burning:
		v.burn_timer -= dt
		_spawn_fire(v.pos.x, 0.4, v.pos.z, 2)
		if v.burn_timer <= 0.0:
			var mine: bool = in_car == v
			_explode(v.pos.x, 1.0, v.pos.z)
			v.node.queue_free()
			vehicles.erase(v)
			if mine:
				in_car = null
				var bd: Vector3 = world.nearest_dock(v.pos)
				if bd.x < 1e8:
					player_pos = Vector3(bd.x, 0, bd.z)
				player_hp -= 25.0
				player_node.visible = true


# =====================================================================
# President motorcade
# =====================================================================
## Lay out the motorcade route — the residence gate, down the road, across the
## causeway, to the airport forecourt.
func _build_convoy_route() -> void:
	var pts := [
		Vector2(-28.0, 320.0),    # the mansion driveway
		Vector2(-28.0, 340.0),    # onto the estate's main drive
		Vector2(18.0, 340.0),     # through the estate gate
		Vector2(50.0, 340.0),     # across the causeway onto the airport
		Vector2(CityWorld.AIRPORT.x, CityWorld.AIRPORT.z + 26.0),  # airport forecourt
	]
	convoy_route = PackedVector3Array()
	for p in pts:
		convoy_route.append(Vector3(p.x, 0.0, p.y))
	_convoy_route_len = 0.0
	for i in range(convoy_route.size() - 1):
		_convoy_route_len += convoy_route[i].distance_to(convoy_route[i + 1])


## Position + heading at distance `d` along the motorcade route.
func _sample_route(d: float) -> Dictionary:
	if convoy_route.size() < 2:
		return {"pos": Vector3.ZERO, "yaw": 0.0}
	d = clampf(d, 0.0, _convoy_route_len)
	var acc := 0.0
	for i in range(convoy_route.size() - 1):
		var a: Vector3 = convoy_route[i]
		var b: Vector3 = convoy_route[i + 1]
		var seg := a.distance_to(b)
		if d <= acc + seg or i == convoy_route.size() - 2:
			var t: float = 0.0 if seg < 0.01 else clampf((d - acc) / seg, 0.0, 1.0)
			var dir := b - a
			return {"pos": a.lerp(b, t), "yaw": atan2(dir.x, dir.z)}
		acc += seg
	return {"pos": convoy_route[0], "yaw": 0.0}


func _make_motorcade_vehicle(pos: Vector3, yaw: float, is_limo: bool) -> Dictionary:
	var node := CarMesh.build(0x0a0a10, "sedan" if is_limo else "suv", false,
		head_mat, tail_mat)
	if is_limo:
		node.scale = Vector3(1.05, 1.05, 1.7)
	node.position = pos
	node.rotation.y = yaw
	add_child(node)
	return {
		"node": node, "pos": pos, "yaw": yaw, "speed": 0.0, "max_speed": 30.0,
		"hp": 280.0 if is_limo else 150.0, "max_hp": 280.0 if is_limo else 150.0,
		"style": "sedan", "burning": false, "burn_timer": 0.0, "is_plane": false,
		"motorcade": true, "is_limo": is_limo,
	}


## Spawn the President, his bodyguards and the convoy at the residence.
func _begin_motorcade() -> void:
	pres_aggro = false
	convoy_prog = 0.0
	var start := _sample_route(0.0)
	vehicles.append(_make_motorcade_vehicle(start.pos, start.yaw, true))
	for k in 3:
		vehicles.append(_make_motorcade_vehicle(start.pos, start.yaw, false))
	var pnode := Human.build(0xe7c7a0, 0x1b2740, 0x141d2e, 0x3a3a3a)
	pnode.scale = Vector3(1.08, 1.08, 1.08)
	add_child(pnode)
	president = {
		"node": pnode, "pos": start.pos, "yaw": start.yaw,
		"hp": 240.0, "max_hp": 240.0, "cash": 0, "is_president": true,
		"walk_phase": 0.0, "guards": [],
	}
	vips.append(president)
	for gi in 6:
		var gnode := Human.build(0xd9a878, 0x14141a, 0x101014, 0x101010, 0x101014)
		add_child(gnode)
		var glimbs: Dictionary = gnode.get_meta("limbs")
		var gholder := Node3D.new()
		gholder.position = Vector3(0.0, -0.86, 0.18)
		glimbs.armR.add_child(gholder)
		gholder.add_child(_weapon_model(2))
		guards.append({
			"node": gnode, "pos": start.pos, "yaw": start.yaw,
			"hp": 120.0, "max_hp": 120.0, "walk_phase": randf() * TAU,
			"last_shot": 0.0, "motorcade": true, "vip": president, "aggro": false,
			"slot": gi,
		})
	pres_state = "toairport"
	_show_objective("The President's motorcade has rolled out of the residence, bound for the airport. Take him down to seize the city.", 7.0)


func _update_president(dt: float) -> void:
	if pres_state == "home":
		pres_timer -= dt
		if pres_timer <= 0.0:
			_begin_motorcade()
		return
	# The President was assassinated mid-run — tear the motorcade down.
	if president == null:
		_end_motorcade()
		return
	var stopped := pres_state == "atairport" or pres_state == "athome"
	match pres_state:
		"toairport":
			convoy_prog = minf(_convoy_route_len, convoy_prog + CONVOY_SPEED * dt)
			if convoy_prog >= _convoy_route_len:
				pres_state = "atairport"
				pres_timer = 9.0
				_show_objective("The President has stepped out at the airport.", 4.0)
		"atairport":
			pres_timer -= dt
			if pres_timer <= 0.0:
				pres_state = "tohome"
		"tohome":
			convoy_prog = maxf(0.0, convoy_prog - CONVOY_SPEED * dt)
			if convoy_prog <= 0.0:
				pres_state = "athome"
				pres_timer = 6.0
		"athome":
			pres_timer -= dt
			if pres_timer <= 0.0:
				_end_motorcade()
				return
	# Place the convoy along the route — limo leading, escorts trailing.
	var limo = null
	var escorts: Array = []
	for v in vehicles:
		if v.get("motorcade", false):
			if v.get("is_limo", false):
				limo = v
			else:
				escorts.append(v)
	var ordered: Array = ([limo] if limo != null else []) + escorts
	for i in ordered.size():
		var mv = ordered[i]
		var s := _sample_route(convoy_prog - i * CONVOY_SPACING)
		mv.pos = s.pos
		mv.yaw = s.yaw
		mv.node.position = s.pos
		mv.node.rotation.y = s.yaw
	var anchor: Vector3 = limo.pos if limo != null else president.pos
	var ayaw: float = limo.yaw if limo != null else president.yaw
	# The President rides the limo, and steps out beside it whenever it stops.
	if stopped and limo != null:
		var side := Vector3(cos(ayaw), 0.0, -sin(ayaw))
		president.pos = anchor + side * 3.2
		president.node.position = Vector3(president.pos.x, 0.0, president.pos.z)
	else:
		president.pos = anchor
		president.node.position = Vector3(anchor.x, 0.95, anchor.z)
	president.yaw = ayaw
	president.node.rotation.y = ayaw
	president.walk_phase += dt * 4.0
	Human.animate(president.node, president.walk_phase, false, 0.0, 0.0)
	# The detail turns hostile the instant the President is hit.
	if president.hp < president.max_hp and not pres_aggro:
		pres_aggro = true
		if not city_owned:
			GameState.wanted = 5.0
			wanted_decay = 0.0
		_show_objective("Shots fired at the President! His entire detail is on you.", 5.0)
	# Bodyguards ring the motorcade and return fire when provoked.
	for g in guards:
		if not g.get("motorcade", false):
			continue
		var ctr: Vector3 = president.pos if stopped else anchor
		var ga := float(g.slot) / 6.0 * TAU
		g.pos = Vector3(ctr.x + cos(ga) * 3.0, 0.0, ctr.z + sin(ga) * 3.0)
		g.node.position = g.pos
		if pres_aggro:
			g.yaw = atan2(player_pos.x - g.pos.x, player_pos.z - g.pos.z)
			if _now - g.last_shot > 1.0 \
				and Vector2(player_pos.x - g.pos.x, player_pos.z - g.pos.z).length() < 75.0:
				g.last_shot = _now + randf() * 0.5
				var from := Vector3(g.pos.x, 1.4, g.pos.z)
				var aim := (Vector3(player_pos.x, 1.2, player_pos.z) - from).normalized()
				aim.x += (randf() - 0.5) * 0.07
				aim.z += (randf() - 0.5) * 0.07
				_spawn_bullet(from, aim.normalized(), WeaponDB.LIST[2], "cop")
				AudioFX.shoot()
		else:
			g.yaw = ayaw
		g.node.rotation.y = g.yaw
		g.walk_phase += dt * 6.0
		Human.animate(g.node, g.walk_phase, not stopped, 0.5, 0.3)
	# A destroyed convoy vehicle burns out and drops away.
	for cv in ordered:
		if cv.hp <= 0.0 and not cv.burning:
			cv.burning = true
			cv.burn_timer = 1.4
		if cv.burning:
			cv.burn_timer -= dt
			_spawn_fire(cv.pos.x, 0.4, cv.pos.z, 2)
			if cv.burn_timer <= 0.0:
				_explode(cv.pos.x, 1.0, cv.pos.z)
				cv.node.queue_free()
				vehicles.erase(cv)


## Despawn the whole motorcade and arm the timer for the next run.
func _end_motorcade() -> void:
	for v in vehicles.duplicate():
		if v.get("motorcade", false):
			if is_instance_valid(v.node):
				v.node.queue_free()
			vehicles.erase(v)
	for g in guards.duplicate():
		if g.get("motorcade", false):
			if is_instance_valid(g.node):
				g.node.queue_free()
			guards.erase(g)
	if president != null:
		if president in vips:
			vips.erase(president)
		if is_instance_valid(president.node):
			president.node.queue_free()
		president = null
	pres_state = "home"
	pres_timer = 110.0 + randf() * 70.0
	pres_aggro = false
	convoy_prog = 0.0


## The President has been killed — the city falls to the player.
func _kill_president(v: Dictionary) -> void:
	_spawn_blood(v.pos.x, 1.2, v.pos.z, 48)
	if is_instance_valid(v.node):
		v.node.queue_free()
	president = null
	_win_city()


func _win_city() -> void:
	if city_owned:
		return
	city_owned = true
	GameState.money += 5_000_000_000
	GameState.wanted = 0.0
	# Presidential protection — 1000x body armour, topped up and held full.
	player_max_armor = 100000.0
	player_armor = player_max_armor
	player_hp = player_max_hp
	for c in cops:
		if is_instance_valid(c.node):
			c.node.queue_free()
	cops.clear()
	pres_aggro = false
	AudioFX.coin()
	hud.show_victory()
	_form_presidential_detail()
	_show_objective("THE PRESIDENT IS DEAD — VICE BEACH IS YOURS. +$5,000,000,000, the police stand down, the treasury pays you, and your own bodyguard detail now escorts you.", 10.0)


## As the new President, the player gets a personal detail: bodyguards on foot
## and a motorcade of escort cars that forms up around the car they drive.
func _form_presidential_detail() -> void:
	for gi in 4:
		var gnode := Human.build(0xd9a878, 0x1a1a20, 0x141418, 0x121212, 0x141418)
		add_child(gnode)
		var glimbs: Dictionary = gnode.get_meta("limbs")
		var holder := Node3D.new()
		holder.position = Vector3(0.0, -0.86, 0.18)
		glimbs.armR.add_child(holder)
		holder.add_child(_weapon_model(2))
		my_guards.append({
			"node": gnode, "pos": Vector3(player_pos.x, 0.0, player_pos.z),
			"yaw": 0.0, "walk_phase": randf() * TAU, "slot": gi, "last_shot": 0.0,
		})
	for ei in 4:
		var enode := CarMesh.build(0x0a0a10, "suv", false, head_mat, tail_mat)
		add_child(enode)
		enode.position = Vector3(player_pos.x, 0.0, player_pos.z)
		my_convoy.append({
			"node": enode, "pos": Vector3(player_pos.x, 0.0, player_pos.z),
			"yaw": 0.0, "slot": ei,
		})


## Drive the President-player's escort: bodyguards ring him on foot; the escort
## cars hang back, then roll into a front-and-back convoy once he settles in a car.
func _update_my_detail(dt: float) -> void:
	if not city_owned:
		return
	var in_ground_car: bool = in_car != null and not in_car.is_plane \
		and not in_car.get("is_boat", false) and not in_car.get("is_heli", false)
	if in_ground_car:
		_convoy_form += dt
	else:
		_convoy_form = 0.0
	var on_foot: bool = in_car == null and not parachuting and suit_state != "on"
	# Find the nearest hostile attacking the President — a cop, or an aggroed
	# bodyguard or VIP.
	var threat = null
	var threat_d := 60.0
	for t in cops:
		if t.hp > 0.0:
			var td: float = Vector2(t.pos.x - player_pos.x, t.pos.z - player_pos.z).length()
			if td < threat_d:
				threat_d = td
				threat = t
	for t in guards + vips:
		if t.hp > 0.0 and t.get("aggro", false):
			var td: float = Vector2(t.pos.x - player_pos.x, t.pos.z - player_pos.z).length()
			if td < threat_d:
				threat_d = td
				threat = t
	# Bodyguards ring the President — and gun down anyone who attacks him.
	for g in my_guards:
		if not on_foot:
			g.node.visible = false
			g.pos = Vector3(player_pos.x, 0.0, player_pos.z)
			continue
		g.node.visible = true
		if threat != null:
			# Combat — close on the attacker and open fire.
			var cdx: float = threat.pos.x - g.pos.x
			var cdz: float = threat.pos.z - g.pos.z
			var cdist: float = sqrt(cdx * cdx + cdz * cdz)
			g.yaw = atan2(cdx, cdz)
			var advancing: bool = cdist > 12.0
			if advancing:
				var cstep: float = minf(cdist - 12.0, 7.5 * dt)
				var cnx: float = g.pos.x + sin(g.yaw) * cstep
				var cnz: float = g.pos.z + cos(g.yaw) * cstep
				if not world.collides_at(cnx, g.pos.z, 0.4):
					g.pos.x = cnx
				if not world.collides_at(g.pos.x, cnz, 0.4):
					g.pos.z = cnz
			if cdist < 48.0 and _now - g.last_shot > 0.65:
				g.last_shot = _now + randf() * 0.35
				var cfrom := Vector3(g.pos.x, 1.4, g.pos.z)
				var caim := (Vector3(threat.pos.x, 1.2, threat.pos.z) - cfrom).normalized()
				caim.x += (randf() - 0.5) * 0.05
				caim.z += (randf() - 0.5) * 0.05
				# Source "player" — friendly fire passes the President by and
				# damages the hostiles in npcs/cops/guards/vips.
				_spawn_bullet(cfrom, caim.normalized(), WeaponDB.LIST[2], "player")
				AudioFX.shoot()
			g.walk_phase += dt * 7.5
			Human.animate(g.node, g.walk_phase, advancing, 0.55, 0.34)
			g.node.position = g.pos
			g.node.rotation.y = g.yaw
		else:
			# Escort — ring the President.
			var ga: float = float(g.slot) / float(my_guards.size()) * TAU + _now * 0.25
			var tx: float = player_pos.x + cos(ga) * 3.8
			var tz: float = player_pos.z + sin(ga) * 3.8
			var gdx: float = tx - g.pos.x
			var gdz: float = tz - g.pos.z
			var gd: float = sqrt(gdx * gdx + gdz * gdz)
			var gmoving: bool = gd > 0.5
			if gmoving:
				g.yaw = atan2(gdx, gdz)
				var gstep: float = minf(gd, 6.5 * dt)
				var gnx: float = g.pos.x + sin(g.yaw) * gstep
				var gnz: float = g.pos.z + cos(g.yaw) * gstep
				if not world.collides_at(gnx, g.pos.z, 0.4):
					g.pos.x = gnx
				if not world.collides_at(g.pos.x, gnz, 0.4):
					g.pos.z = gnz
			g.walk_phase += dt * 7.0
			Human.animate(g.node, g.walk_phase, gmoving, 0.5, 0.3)
			g.node.position = g.pos
			g.node.rotation.y = g.yaw
	# Escort vehicles — loose until the President settles in a car, then convoy up.
	for e in my_convoy:
		var target: Vector3
		var deadzone: float
		if in_ground_car and _convoy_form > 3.0:
			# Two cars ahead, two behind, along the President's heading.
			var fwd := Vector3(sin(in_car.yaw), 0.0, cos(in_car.yaw))
			var rgt := Vector3(cos(in_car.yaw), 0.0, -sin(in_car.yaw))
			var ahead := [16.0, 30.0, -16.0, -30.0]
			var sidesign := 1.0 if e.slot % 2 == 0 else -1.0
			target = in_car.pos + fwd * ahead[e.slot] + rgt * (sidesign * 2.4)
			deadzone = 0.8
		else:
			var ea: float = float(e.slot) / float(my_convoy.size()) * TAU
			target = Vector3(player_pos.x + cos(ea) * 13.0, 0.0,
				player_pos.z + sin(ea) * 13.0)
			deadzone = 15.0
		var edx: float = target.x - e.pos.x
		var edz: float = target.z - e.pos.z
		var ed: float = sqrt(edx * edx + edz * edz)
		if ed > deadzone:
			e.yaw = atan2(edx, edz)
			var estep: float = clampf(ed * 2.2, 6.0, 48.0) * dt
			var enx: float = e.pos.x + sin(e.yaw) * estep
			var enz: float = e.pos.z + cos(e.yaw) * estep
			if not world.collides_at(enx, e.pos.z, 1.6):
				e.pos.x = enx
			if not world.collides_at(e.pos.x, enz, 1.6):
				e.pos.z = enz
		e.node.position = e.pos
		e.node.rotation.y = e.yaw


func _make_helicopter(x: float, z: float, yaw: float) -> Dictionary:
	# A low-poly utility helicopter — nose points +Z. Glass-bubble cockpit,
	# tail boom + fin, landing skids, and a spinning main + tail rotor.
	var g := Node3D.new()
	var body_m := Build.mat(Build.hex(0x2b4a63), 0.45, 0.3)
	var accent_m := Build.mat(Build.hex(0xe08a2c), 0.4, 0.2)
	var dark_m := Build.mat(Build.hex(0x26292e), 0.5, 0.4)
	var metal_m := Build.mat(Build.hex(0x8e9298), 0.3, 0.7)
	var glass_m := Build.mat(Build.hex(0x141d28), 0.1, 0.4)
	glass_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_m.albedo_color.a = 0.65

	var fy := 2.4
	var fus := Build.box(2.6, 2.6, 6.2, body_m)
	fus.position = Vector3(0, fy, 0.2)
	g.add_child(fus)
	var belly := Build.sphere(1.5, body_m)
	belly.scale = Vector3(1.0, 0.7, 1.4)
	belly.position = Vector3(0, fy - 0.7, 0.6)
	g.add_child(belly)
	var cockpit := Build.sphere(1.5, glass_m)
	cockpit.scale = Vector3(0.95, 0.95, 1.05)
	cockpit.position = Vector3(0, fy + 0.2, 2.7)
	g.add_child(cockpit)
	var stripe := Build.box(2.68, 0.5, 6.24, accent_m)
	stripe.position = Vector3(0, fy + 0.7, 0.2)
	g.add_child(stripe)
	var boom := Build.box(0.7, 0.7, 6.2, body_m)
	boom.position = Vector3(0, fy + 0.5, -5.5)
	g.add_child(boom)
	var fin := Build.box(0.34, 2.4, 1.6, body_m)
	fin.position = Vector3(0, fy + 1.6, -8.2)
	g.add_child(fin)
	var fin_acc := Build.box(0.36, 1.2, 1.0, accent_m)
	fin_acc.position = Vector3(0, fy + 2.2, -8.4)
	g.add_child(fin_acc)
	for sx in [-1.35, 1.35]:
		var skid := Build.box(0.24, 0.24, 5.0, metal_m)
		skid.position = Vector3(sx, fy - 1.95, 0.3)
		g.add_child(skid)
		for cz in [-1.4, 1.8]:
			var strut := Build.cyl(0.1, 0.1, 1.6, 6, metal_m)
			strut.position = Vector3(sx * 0.78, fy - 1.2, cz)
			strut.rotation.z = sx * 0.32
			g.add_child(strut)
	var mast := Build.cyl(0.22, 0.22, 1.0, 8, dark_m)
	mast.position = Vector3(0, fy + 1.9, 0.2)
	g.add_child(mast)

	# Main rotor — a node that spins around Y.
	var rotor := Node3D.new()
	rotor.position = Vector3(0, fy + 2.4, 0.2)
	g.add_child(rotor)
	var hub := Build.cyl(0.4, 0.4, 0.3, 8, dark_m)
	rotor.add_child(hub)
	for bi in 3:
		var blade := Build.box(0.55, 0.1, 11.5, dark_m)
		blade.position = Vector3(0, 0.1, 0)
		blade.rotation.y = bi * TAU / 3.0
		rotor.add_child(blade)

	# Tail rotor — a node that spins around X.
	var tail_rotor := Node3D.new()
	tail_rotor.position = Vector3(0.5, fy + 1.4, -8.2)
	g.add_child(tail_rotor)
	for bi in 2:
		var tblade := Build.box(0.14, 2.6, 0.34, dark_m)
		tblade.rotation.x = bi * PI / 2.0
		tail_rotor.add_child(tblade)

	g.position = Vector3(x, 0, z)
	g.rotation.y = yaw
	add_child(g)
	return {
		"node": g, "pos": Vector3(x, 0, z), "yaw": yaw, "pitch": 0.0, "roll": 0.0,
		"speed": 0.0, "vy": 0.0, "throttle": 0.0,
		"max_speed": 46.0, "max_alt": 240.0,
		"hp": 150.0, "max_hp": 150.0,
		"burning": false, "burn_timer": 0.0,
		"is_plane": true, "is_heli": true, "on_ground": true,
		"propeller": null, "rotor": rotor, "tail_rotor": tail_rotor,
		"radius": 3.4, "cam_dist": 15.0,
	}


func _spawn_vehicles(n: int) -> void:
	for i in n:
		for tries in 30:
			var gx := randi() % CityWorld.GRID
			var gz := randi() % CityWorld.GRID
			var on_x := randf() < 0.5
			var x: float
			var z: float
			if on_x:
				x = -CityWorld.WORLD_HALF + gx * CityWorld.BLOCK
				z = -CityWorld.WORLD_HALF + gz * CityWorld.BLOCK + CityWorld.BLOCK / 2.0
			else:
				x = -CityWorld.WORLD_HALF + gx * CityWorld.BLOCK + CityWorld.BLOCK / 2.0
				z = -CityWorld.WORLD_HALF + gz * CityWorld.BLOCK
			if world.collides_at(x, z, 2.0):
				continue
			var v := _make_vehicle(x, z, VEHICLE_COLORS.pick_random(),
				TRAFFIC_STYLES.pick_random())
			v.yaw = 0.0 if on_x else PI / 2.0
			v.node.rotation.y = v.yaw
			vehicles.append(v)
			break


func _spawn_airport_aircraft() -> void:
	# Big airliner at the near end of the main runway, nose pointing down it.
	var a: Dictionary = CityWorld.RUNWAY_A
	vehicles.append(_make_plane(a.x, a.z - a.len / 2.0 + 16.0, 0.0, 1.8))
	# Smaller plane on the secondary runway.
	var b: Dictionary = CityWorld.RUNWAY_B
	vehicles.append(_make_plane(b.x, b.z - b.len / 2.0 + 12.0, 0.0, 1.0))
	# Helicopter parked on the airport helipad.
	var hp: Dictionary = CityWorld.HELIPAD
	vehicles.append(_make_helicopter(hp.x, hp.z, 0.0))


# =====================================================================
# Day / night
# =====================================================================
func _update_daynight() -> void:
	var t := (GameState.time_min - 360.0) / 1440.0 * TAU
	var elev := sin(t)
	var elev_angle := asin(clamp(elev, -1.0, 1.0))
	var theta := GameState.time_min / 1440.0 * TAU
	sun.rotation = Vector3(-elev_angle, theta, 0.0)
	sun.light_energy = max(0.05, elev * 1.1 + 0.35)

	var day := Color("5c7088")
	var dusk := Color("9a6850")
	var night := Color("0a0a22")
	var fog: Color
	if elev > 0.2:
		fog = day
	elif elev > -0.1:
		fog = dusk.lerp(day, (elev + 0.1) / 0.3)
	else:
		fog = night.lerp(dusk, (elev + 1.0) / 0.9)
	env.fog_light_color = fog

	var dayk := clampf((elev + 0.15) / 0.5, 0.0, 1.0)
	sky_mat.sky_top_color = Color(0.02, 0.03, 0.09).lerp(Color(0.17, 0.36, 0.66), dayk)
	sky_mat.sky_horizon_color = Color(0.07, 0.05, 0.13).lerp(Color(0.62, 0.68, 0.76), dayk)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.ground_bottom_color = sky_mat.sky_horizon_color.darkened(0.4)
	env.ambient_light_energy = 0.15 + dayk * 0.7

	var night_amt := clampf(1.0 - (elev + 0.05) * 2.5, 0.0, 1.0)
	world.window_mat.emission_energy_multiplier = night_amt * 1.2
	for m in world.lamp_mats:
		m.emission_energy_multiplier = night_amt * 2.5
	head_mat.emission_energy_multiplier = 0.06 + night_amt * 0.6
	tail_mat.emission_energy_multiplier = 0.08 + night_amt * 0.45
	if world.beacon_mat != null:
		world.beacon_mat.emission_energy_multiplier = 0.6 + night_amt * 0.6 + sin(_now * 6.0) * 0.3
	if world.sign_mat != null:
		world.sign_mat.emission_energy_multiplier = 0.25 + night_amt * 0.6


# =====================================================================
# Camera & HUD
# =====================================================================
func _update_camera() -> void:
	if aiming:
		# First-person zoomed aim — camera rides at the player's eye, looking
		# straight down the crosshair; the body is hidden so it never blocks.
		player_node.visible = false
		if suit_node != null and suit_state == "on":
			suit_node.visible = false
		var eye := Vector3(player_pos.x, player_pos.y + 1.62, player_pos.z)
		var fwd := Vector3(
			-sin(cam_yaw) * cos(cam_pitch),
			-sin(cam_pitch),
			-cos(cam_yaw) * cos(cam_pitch))
		camera.position = camera.position.lerp(eye, 0.5)
		camera.look_at(camera.position + fwd)
		camera.fov = lerp(camera.fov, CAM_FOV_AIM, 0.35)
		return
	if suit_node != null and suit_state == "on":
		suit_node.visible = true
	if in_car == null and not parachuting and suit_state == "none":
		player_node.visible = true
	camera.fov = lerp(camera.fov, CAM_FOV_HIP, 0.35)
	var is_plane: bool = in_car != null and in_car.is_plane
	var target: Vector3 = in_car.pos if in_car != null else player_pos
	var off := Vector3(
		sin(cam_yaw) * cam_dist * cos(cam_pitch),
		cam_dist * sin(cam_pitch) + 2.0,
		cos(cam_yaw) * cam_dist * cos(cam_pitch))
	var desired := Vector3(target.x + off.x, max(1.2, target.y + off.y), target.z + off.z)
	camera.position = camera.position.lerp(desired, 0.12 if is_plane else 0.15)
	var look_h := 1.0 if is_plane else 1.5
	camera.look_at(Vector3(target.x, target.y + look_h, target.z))


func _push_hud() -> void:
	var w: Dictionary = WeaponDB.LIST[GameState.weapon_idx]
	var ammo := GameState.get_ammo(w)
	var speed_label := "SPD"
	var speed_val := 0.0
	var show_speedo := false
	var speed_kmh := 0.0
	var speed_frac := 0.0
	if in_car != null:
		if in_car.is_plane:
			speed_label = "ALT"
			speed_val = in_car.pos.y
		else:
			speed_val = abs(in_car.speed) * 3.6
			# Ground car — drive the dashboard speedometer.
			show_speedo = true
			speed_kmh = abs(in_car.speed) * 3.6
			var gauge_max: float = maxf(in_car.max_speed, 1.0) * 1.7 * 3.6
			speed_frac = speed_kmh / gauge_max
	elif suit_state == "on":
		speed_label = "ALT"
		speed_val = player_pos.y
	var map_pos: Vector3 = in_car.pos if in_car != null else player_pos
	var map_yaw: float = in_car.yaw if in_car != null else player_yaw
	var pres_out: bool = pres_state != "home" and president != null
	hud.update_hud({
		"pres_active": pres_out,
		"pres_x": president.pos.x if pres_out else 0.0,
		"pres_z": president.pos.z if pres_out else 0.0,
		"money": GameState.money,
		"wanted": GameState.wanted,
		"time_min": GameState.time_min,
		"hp": player_hp, "hp_max": player_max_hp,
		"armor": player_armor, "armor_max": player_max_armor,
		"weapon": w.name,
		"ammo": ("∞" if ammo == INF else str(int(ammo))),
		"speed_label": speed_label, "speed_val": speed_val,
		"show_speedo": show_speedo, "speed_kmh": speed_kmh, "speed_frac": speed_frac,
		"waypoint": _waypoint_text(),
		"map_x": map_pos.x, "map_z": map_pos.z, "map_yaw": map_yaw,
		"racing": RaceManager.is_active(),
		"lap": RaceManager.lap,
		"total_laps": RaceManager.total_laps,
		"lap_time": RaceManager.format_time(RaceManager.lap_time),
		"best_lap": RaceManager.format_time(RaceManager.best_lap),
		"last_lap": RaceManager.format_time(RaceManager.last_lap),
		"drift": RaceManager.drift_score,
		"on_track": RaceManager.on_track,
		"race_rank": race_rank, "race_total": race_total,
	})


func _waypoint_text() -> String:
	# Point at the President while his motorcade is out, otherwise the airport.
	var label := "AIRPORT"
	var tx: float = CityWorld.AIRPORT.x
	var tz: float = CityWorld.AIRPORT.z
	if pres_state != "home" and president != null:
		label = "PRESIDENT"
		tx = president.pos.x
		tz = president.pos.z
	var dx := tx - player_pos.x
	var dz := tz - player_pos.z
	var dist := sqrt(dx * dx + dz * dz)
	var ang := atan2(dx, dz)
	var dirs := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var idx := int(round(fposmod(ang, TAU) / (PI / 4.0))) % 8
	return "%s %dm %s" % [label, int(round(dist)), dirs[idx]]


func _show_objective(text: String, secs := 3.5) -> void:
	hud.show_objective(text, secs)
