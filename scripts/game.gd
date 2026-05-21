extends Node3D
## Vice Beach 3D — main game orchestrator.
## Faithful Godot port of the Three.js prototype (game.js): procedural city,
## third-person player, cars + plane, 9 weapons, NPCs, police + wanted system.

# ---------------- Tuning constants (mirrors game.js) ----------------
# Realistic car colors — black, white, silver, gunmetal, maroon, navy, dark olive.
const VEHICLE_COLORS := [0x1b1b1d, 0xdcdcda, 0x9a9ca0, 0x4b4e54, 0x5e2a2a, 0x2b384e, 0x3a4438]
const NPC_SKINS := [0xf4c28a, 0xd99770, 0xa87657, 0x7a5a40]
# Muted, earthy NPC clothing.
const NPC_SHIRTS := [0x8a4f3e, 0x47586a, 0x586a4a, 0x9c8a64, 0x3f4a58, 0x6f6f6c, 0xb0a690, 0x5a4c46]
const NPC_PANTS := [0x2a2e36, 0x33384a, 0x4a2a1a, 0x35435a, 0x4a4a44]
const NPC_HAIR := [0x2a1a08, 0x4a2a1a, 0xaa8866, 0x222222, 0xccaa44, 0xddccaa]

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
var terminal_open := false       # true while any kiosk terminal is on screen
var _near_exchange := false      # on foot and within reach of the exchange kiosk
var _near_dealership := false    # on foot and within reach of the dealership kiosk
var _near_stark := false         # on foot and within reach of the Stark lab kiosk
var _near_realtor := false       # on foot and within reach of the realtor kiosk
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

	dealership_terminal = DealershipTerminal.new()
	add_child(dealership_terminal)
	dealership_terminal.closed.connect(_on_terminal_closed)
	dealership_terminal.spawn_requested.connect(_spawn_owned_vehicle)

	suit_terminal = SuitTerminal.new()
	add_child(suit_terminal)
	suit_terminal.closed.connect(_on_terminal_closed)

	realtor_terminal = RealtorTerminal.new()
	add_child(realtor_terminal)
	realtor_terminal.closed.connect(_on_terminal_closed)

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
	Garage.reset()
	terminal_open = false
	_near_exchange = false
	_near_dealership = false
	_near_stark = false
	_near_realtor = false
	_owned_spawn = null
	var s := world.find_safe_spawn()
	player_pos = Vector3(s.x, 0, s.y)
	player_node.position = player_pos
	player_node.visible = true
	_spawn_vehicles(40)
	_spawn_airport_aircraft()
	for i in 40:
		_spawn_npc()
	_spawn_vip_groups(VIP_TARGET)
	_spawn_iron_suit()
	hud.enter_game()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_show_objective("Rich VIPs roam the city - rob them for cash. An IRON MAN SUIT stands nearby - step onto it to fly. Downtown is the place to spend: STOCK EXCHANGE, VICE AUTOS (cars), STARK INDUSTRIES (suit upgrades) and VICE REALTY (safehouses) - press E at each kiosk.", 11.0)


func _die() -> void:
	GameState.paused = true
	GameState.money = max(0, GameState.money - (10 + randi() % 6))
	hud.show_death()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _respawn() -> void:
	hud.hide_death()
	GameState.paused = false
	GameState.wanted = 0.0
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
			elif suit_state == "none":
				_try_enter_exit()
		KEY_E:
			if not terminal_open and in_car == null \
				and suit_state == "none" and not parachuting:
				if _near_exchange:
					_open_terminal()
				elif _near_dealership:
					_open_dealership()
				elif _near_stark:
					_open_stark()
				elif _near_realtor:
					_open_realtor()
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


## Drop the player's owned car `catalog_idx` onto the dealership lot. The
## previous lot car (if still parked and not being driven) is cleared first so
## owned spawns never pile up.
func _spawn_owned_vehicle(catalog_idx: int) -> void:
	var car: Dictionary = VehicleCatalog.LIST[catalog_idx]
	if _owned_spawn != null and _owned_spawn != in_car and _owned_spawn in vehicles:
		_owned_spawn.node.queue_free()
		vehicles.erase(_owned_spawn)
	_owned_spawn = null
	var sx: float = CityWorld.DEALERSHIP.x + 7.0
	var sz: float = CityWorld.DEALERSHIP.z + 2.0
	var v := _make_vehicle(sx, sz, car.color)
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
		if in_car.get("is_heli", false):
			_update_helicopter(in_car, dt)
		elif in_car.is_plane:
			_update_plane(in_car, dt)
		else:
			_update_car(in_car, dt)
	elif suit_state == "suiting":
		_update_suiting(dt)
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
	aiming = in_car == null and not parachuting and suit_state != "suiting" and _key(KEY_SPACE)

	# Idle bob/spin for the parked Iron Man suit waiting to be worn.
	if suit_node != null and suit_state == "none":
		suit_node.rotation.y += dt * 0.7
		suit_node.position.y = 0.06 + sin(_now * 2.0) * 0.12

	_update_shooting()
	_update_npcs(dt)
	_update_cops(dt)
	_update_vips(dt)
	_update_guards(dt)
	_update_wanted(dt)
	_update_bullets(dt)
	_update_particles(dt)
	_update_pickups(dt)

	if GameState.wanted == 0.0 and player_hp < player_max_hp:
		player_hp = min(player_max_hp, player_hp + dt * 4.0)
	if player_hp <= 0.0:
		_die()
		return

	_update_daynight()
	for c in world.clouds:
		c.node.position.x += c.drift * dt
		if c.node.position.x > CityWorld.WORLD:
			c.node.position.x = -CityWorld.WORLD
	_update_camera()
	_push_hud()


# ---------------- On foot ----------------
func _update_on_foot(dt: float) -> void:
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
		if not world.collides_at(player_pos.x + dx, player_pos.z, 0.4):
			player_pos.x += dx
		if not world.collides_at(player_pos.x, player_pos.z + dz, 0.4):
			player_pos.z += dz
		player_yaw = atan2(dx, dz)
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
		_show_objective("Trading terminal - press E to buy and sell stocks.", 4.0)
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


# ---------------- Car ----------------
func _update_car(v: Dictionary, dt: float) -> void:
	var accel := (1.0 if _key(KEY_W) else 0.0) - (1.0 if _key(KEY_S) else 0.0)
	var turn := (1.0 if _key(KEY_A) else 0.0) - (1.0 if _key(KEY_D) else 0.0)
	var boost := 1.7 if _key(KEY_SHIFT) else 1.0
	var handbrake := _key(KEY_SPACE)

	v.speed += accel * 35.0 * dt
	v.speed *= 1.0 - dt * (4.0 if handbrake else 0.6)
	var max_s: float = v.max_speed * boost
	v.speed = clamp(v.speed, -max_s / 2.0, max_s)
	if abs(v.speed) > 1.0 and randf() < 0.15:
		AudioFX.engine()
	if abs(v.speed) > 0.5:
		var sgn := 1.0 if v.speed > 0.0 else -1.0
		v.yaw += turn * 1.8 * dt * sgn * min(1.0, abs(v.speed) / 6.0)

	var dx: float = sin(v.yaw) * v.speed * dt
	var dz: float = cos(v.yaw) * v.speed * dt
	if not world.collides_at(v.pos.x + dx, v.pos.z, 1.2):
		v.pos.x += dx
	else:
		_spawn_sparks(v.pos.x, 0.8, v.pos.z, 4)
		v.hp -= abs(v.speed) * 0.3
		v.speed *= -0.3
		AudioFX.hit()
	if not world.collides_at(v.pos.x, v.pos.z + dz, 1.2):
		v.pos.z += dz
	else:
		_spawn_sparks(v.pos.x, 0.8, v.pos.z, 4)
		v.hp -= abs(v.speed) * 0.3
		v.speed *= -0.3
		AudioFX.hit()
	v.node.position = v.pos
	v.node.rotation.y = v.yaw

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
		if v.is_plane and v.pos.y > 4.0:
			# Bail out — parachute down; the empty plane is lost.
			var bail := Vector3(v.pos.x, v.pos.y, v.pos.z)
			v.node.queue_free()
			vehicles.erase(v)
			in_car = null
			_deploy_parachute(bail)
			return
		in_car = null
		cam_dist = 6.5
		player_pos = Vector3(v.pos.x + cos(v.yaw + PI / 2.0) * 2.0, 0, v.pos.z + sin(v.yaw + PI / 2.0) * 2.0)
		player_node.visible = true
		_show_objective("On foot. Mouse to aim, click to shoot. Hold Space to zoom into a first-person aim.")
		return
	var best = null
	var best_d := INF
	for v in vehicles:
		if v.burning:
			continue
		var d: float = Vector2(v.pos.x - player_pos.x, v.pos.z - player_pos.z).length()
		var max_d: float = (5.0 + v.radius) if v.is_plane else 4.0
		if d < max_d and d < best_d:
			best_d = d
			best = v
	if best != null:
		in_car = best
		cam_yaw = best.yaw + PI
		player_node.visible = false
		if best.get("is_heli", false):
			cam_dist = best.get("cam_dist", 15.0)
			_show_objective("Helicopter: hold Up to lift straight off and climb, Down to descend. W/S fly forward/back, A/D turn. Release everything to hover. F bails out (parachute).", 8.0)
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
func _build_iron_suit() -> Node3D:
	var g := Node3D.new()
	var red := Build.mat(Build.hex(0xb01a1a), 0.34, 0.55)
	var gold := Build.mat(Build.hex(0xe0ad28), 0.3, 0.7)
	var dark := Build.mat(Build.hex(0x2a2a30), 0.5, 0.5)
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
		var thigh := Build.box(0.27, 0.46, 0.29, red)
		thigh.position.y = -0.225
		leg.add_child(thigh)
		var shin := Build.box(0.25, 0.46, 0.27, gold)
		shin.position.y = -0.675
		leg.add_child(shin)
		var boot := Build.box(0.27, 0.15, 0.42, red)
		boot.position = Vector3(0, -0.95, 0.06)
		leg.add_child(boot)
		pieces.append(boot)
		pieces.append(shin)
		pieces.append(thigh)

	var pelvis := Build.box(0.5, 0.26, 0.33, dark)
	pelvis.position.y = 1.06
	g.add_child(pelvis)
	pieces.append(pelvis)
	var abs_plate := Build.box(0.5, 0.3, 0.36, gold)
	abs_plate.position.y = 1.14
	g.add_child(abs_plate)
	pieces.append(abs_plate)
	var torso := Build.box(0.64, 0.72, 0.4, red)
	torso.position.y = 1.42
	g.add_child(torso)
	pieces.append(torso)
	var reactor := Build.cyl(0.1, 0.1, 0.09, 14, glow)
	reactor.rotation.x = PI / 2.0
	reactor.position = Vector3(0, 1.55, 0.21)
	g.add_child(reactor)
	pieces.append(reactor)
	var shoulders := Build.box(0.88, 0.24, 0.43, red)
	shoulders.position.y = 1.76
	g.add_child(shoulders)
	pieces.append(shoulders)

	var armL := Node3D.new()
	armL.position = Vector3(-0.43, 1.74, 0)
	g.add_child(armL)
	var armR := Node3D.new()
	armR.position = Vector3(0.43, 1.74, 0)
	g.add_child(armR)
	for arm in [armL, armR]:
		var upper := Build.box(0.19, 0.42, 0.19, red)
		upper.position.y = -0.21
		arm.add_child(upper)
		var fore := Build.box(0.18, 0.38, 0.18, gold)
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
	var helmet := Build.box(0.35, 0.37, 0.35, red)
	headG.add_child(helmet)
	pieces.append(helmet)
	var face := Build.box(0.29, 0.24, 0.07, gold)
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


func _begin_suit() -> void:
	suit_state = "suiting"
	suit_timer = 0.0
	suit_armed = false
	player_pos.y = 0.0
	suit_node.position = Vector3(player_pos.x, 0.0, player_pos.z)
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
	player_pos.y = 0.0
	suit_node.position = Vector3(player_pos.x, 0.0, player_pos.z)
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
	_show_objective("Suit powered down — step onto it again to suit up.", 4.0)


func _update_suiting(dt: float) -> void:
	suit_timer += dt
	var pieces: Array = suit_node.get_meta("pieces")
	var rest: Array = suit_node.get_meta("rest")
	suit_node.position = Vector3(player_pos.x, 0.0, player_pos.z)
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


func _update_suit(dt: float) -> void:
	var st := Garage.suit_stats()
	var ascend := (1.0 if _key(KEY_UP) else 0.0) - (1.0 if _key(KEY_DOWN) else 0.0)
	var mx := (1.0 if _key(KEY_D) else 0.0) - (1.0 if _key(KEY_A) else 0.0)
	var mz := (1.0 if _key(KEY_W) else 0.0) - (1.0 if _key(KEY_S) else 0.0)

	# Vertical: Up climbs, Down descends, neither holds a steady hover.
	suit_vy = move_toward(suit_vy, ascend * st.fly_v, 46.0 * dt)
	player_pos.y = clampf(player_pos.y + suit_vy * dt, 0.0, 220.0)
	if player_pos.y <= 0.0:
		player_pos.y = 0.0
		suit_vy = maxf(suit_vy, 0.0)
	var airborne: bool = player_pos.y > 0.7

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
func _spawn_cop(near: Vector3) -> void:
	for tries in 20:
		var ang := randf() * TAU
		var dist := 60.0 + randf() * 40.0
		var x := near.x + cos(ang) * dist
		var z := near.z + sin(ang) * dist
		if world.collides_at(x, z, 1.0):
			continue
		var node := Human.build(0xf4c28a, 0x232f44, 0x14192a, 0x2a1a08, 0x14192a)
		node.position = Vector3(x, 0, z)
		add_child(node)
		cops.append({
			"node": node, "pos": Vector3(x, 0, z), "yaw": 0.0,
			"hp": 80.0, "max_hp": 80.0, "last_shot": 0.0, "walk_phase": randf() * TAU,
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
		if d > 7.0:
			var nx: float = c.pos.x + sin(c.yaw) * 5.0 * dt
			var nz: float = c.pos.z + cos(c.yaw) * 5.0 * dt
			if not world.collides_at(nx, c.pos.z, 0.4):
				c.pos.x = nx
			if not world.collides_at(c.pos.x, nz, 0.4):
				c.pos.z = nz
		c.node.position = c.pos
		c.node.rotation.y = c.yaw
		c.walk_phase += dt * 7.0
		Human.animate(c.node, c.walk_phase, d > 7.0, 0.6, 0.36)
		if d < 60.0 and _now - c.last_shot > 0.7:
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
	if GameState.wanted >= 1.0:
		cop_timer -= dt
		if cop_timer <= 0.0:
			cop_timer = max(4.0, 10.0 - GameState.wanted * 1.4)
			var n: int = max(1, int(GameState.wanted))
			for i in n:
				_spawn_cop(player_pos)
	wanted_decay += dt
	if wanted_decay > 4.0 and GameState.wanted > 0.0:
		GameState.wanted = max(0.0, GameState.wanted - dt * 0.18)
		if GameState.wanted == 0.0:
			_show_objective("You lost the cops.")
			for c in cops:
				c.node.queue_free()
			cops.clear()
	var giveup := 90.0 if GameState.wanted < 2.0 else 180.0
	var keep: Array = []
	for c in cops:
		if c.pos.distance_to(player_pos) > giveup:
			c.node.queue_free()
		else:
			keep.append(c)
	cops = keep


func _raise_wanted(amt: float) -> void:
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
			_spawn_blood(v.pos.x, 1.2, v.pos.z, 22)
			_spawn_pickup(v.pos.x, v.pos.z, v.cash)
			_raise_wanted(3.0)
			_show_objective("VIP down  +$%d" % v.cash, 3.5)
			for g in v.guards:
				g.aggro = true
				g.vip = null
			v.node.queue_free()
			continue
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
func _make_vehicle(x: float, z: float, color: int) -> Dictionary:
	var g := Node3D.new()
	var body_m := Build.mat(Build.hex(color), 0.48, 0.22)
	var glass_m := Build.mat(Build.hex(0x0a1426), 0.08, 0.0)
	glass_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_m.albedo_color.a = 0.85

	var body := Build.box(2.0, 0.55, 4.2, body_m)
	body.position.y = 0.55
	g.add_child(body)
	var hood := Build.box(1.85, 0.35, 1.6, body_m)
	hood.position = Vector3(0, 0.95, 1.2)
	g.add_child(hood)
	var trunk := Build.box(1.85, 0.35, 1.3, body_m)
	trunk.position = Vector3(0, 0.95, -1.3)
	g.add_child(trunk)
	var cabin := Build.box(1.7, 0.68, 1.9, glass_m)
	cabin.position = Vector3(0, 1.3, -0.1)
	g.add_child(cabin)
	var roof := Build.box(1.65, 0.08, 1.4, body_m)
	roof.position = Vector3(0, 1.68, -0.1)
	g.add_child(roof)

	var tire_m := Build.mat(Build.hex(0x0a0a0a), 0.95)
	var rim_m := Build.mat(Build.hex(0xcccccc), 0.25, 0.95)
	for wp in [Vector2(-1, -1.4), Vector2(1, -1.4), Vector2(-1, 1.4), Vector2(1, 1.4)]:
		var tire := Build.cyl(0.42, 0.42, 0.38, 18, tire_m)
		tire.rotation.z = PI / 2.0
		tire.position = Vector3(wp.x, 0.42, wp.y)
		g.add_child(tire)
		var rim := Build.cyl(0.26, 0.26, 0.4, 14, rim_m)
		rim.rotation.z = PI / 2.0
		rim.position = Vector3(wp.x, 0.42, wp.y)
		g.add_child(rim)
	for hx in [-0.65, 0.65]:
		var hl := Build.box(0.36, 0.18, 0.1, head_mat)
		hl.position = Vector3(hx, 0.85, 2.06)
		g.add_child(hl)
	for tx in [-0.7, 0.7]:
		var tl := Build.box(0.32, 0.16, 0.08, tail_mat)
		tl.position = Vector3(tx, 0.85, -2.06)
		g.add_child(tl)

	g.position = Vector3(x, 0, z)
	add_child(g)
	return {
		"node": g, "pos": Vector3(x, 0, z), "yaw": randf() * TAU, "speed": 0.0,
		"max_speed": 28.0, "hp": 100.0, "max_hp": 100.0,
		"burning": false, "burn_timer": 0.0, "is_plane": false, "propeller": null,
	}


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

	var fy := 2.0
	var fus := Build.box(1.8, 2.0, 11.0, body_m)
	fus.position = Vector3(0, fy, 0)
	g.add_child(fus)
	var nose := Build.cyl(0.12, 0.95, 2.6, 12, body_m)
	nose.rotation.x = -PI / 2.0
	nose.position = Vector3(0, fy, 6.6)
	g.add_child(nose)
	var tcone := Build.cyl(0.12, 0.95, 3.0, 12, body_m)
	tcone.rotation.x = PI / 2.0
	tcone.position = Vector3(0, fy + 0.5, -6.7)
	g.add_child(tcone)
	var cockpit := Build.box(1.5, 0.7, 1.8, glass_m)
	cockpit.position = Vector3(0, fy + 0.7, 4.6)
	g.add_child(cockpit)
	for wi in 8:
		var wz := 3.2 - wi * 0.85
		for sx in [-0.96, 0.96]:
			var win := Build.box(0.1, 0.32, 0.42, win_m)
			win.position = Vector3(sx, fy + 0.35, wz)
			g.add_child(win)
	for side in [-1.0, 1.0]:
		var wing := Build.box(7.4, 0.3, 2.8, body_m)
		wing.position = Vector3(side * 4.4, fy - 0.55, -0.4)
		wing.rotation.y = side * 0.34
		g.add_child(wing)
		var wl := Build.box(0.3, 1.5, 1.3, accent_m)
		wl.position = Vector3(side * 8.0, fy + 0.05, -1.7)
		wl.rotation.z = side * 0.5
		g.add_child(wl)
		var eng := Build.cyl(0.62, 0.7, 2.8, 12, dark_m)
		eng.rotation.x = PI / 2.0
		eng.position = Vector3(side * 3.6, fy - 1.15, 0.4)
		g.add_child(eng)
	var fin := Build.box(0.34, 3.4, 2.6, body_m)
	fin.position = Vector3(0, fy + 2.5, -5.6)
	g.add_child(fin)
	var fin_acc := Build.box(0.36, 2.0, 1.4, accent_m)
	fin_acc.position = Vector3(0, fy + 3.1, -6.0)
	g.add_child(fin_acc)
	for side in [-1.0, 1.0]:
		var stab := Build.box(3.4, 0.24, 1.6, body_m)
		stab.position = Vector3(side * 1.9, fy + 1.0, -6.0)
		stab.rotation.y = side * 0.3
		g.add_child(stab)
	for gear in [Vector3(0, 0, 4.6), Vector3(-2.0, 0, -0.6), Vector3(2.0, 0, -0.6)]:
		var strut := Build.cyl(0.12, 0.12, 1.2, 6, metal_m)
		strut.position = Vector3(gear.x, fy - 1.6, gear.z)
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
			var v := _make_vehicle(x, z, VEHICLE_COLORS.pick_random())
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
	if in_car != null:
		if in_car.is_plane:
			speed_label = "ALT"
			speed_val = in_car.pos.y
		else:
			speed_val = abs(in_car.speed) * 3.6
	elif suit_state == "on":
		speed_label = "ALT"
		speed_val = player_pos.y
	var map_pos: Vector3 = in_car.pos if in_car != null else player_pos
	var map_yaw: float = in_car.yaw if in_car != null else player_yaw
	hud.update_hud({
		"money": GameState.money,
		"wanted": GameState.wanted,
		"time_min": GameState.time_min,
		"hp": player_hp, "hp_max": player_max_hp,
		"armor": player_armor, "armor_max": player_max_armor,
		"weapon": w.name,
		"ammo": ("∞" if ammo == INF else str(int(ammo))),
		"speed_label": speed_label, "speed_val": speed_val,
		"waypoint": _waypoint_text(),
		"map_x": map_pos.x, "map_z": map_pos.z, "map_yaw": map_yaw,
	})


func _waypoint_text() -> String:
	var ax: float = CityWorld.AIRPORT.x
	var az: float = CityWorld.AIRPORT.z
	var dx := ax - player_pos.x
	var dz := az - player_pos.z
	var dist := sqrt(dx * dx + dz * dz)
	var ang := atan2(dx, dz)
	var dirs := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var idx := int(round(fposmod(ang, TAU) / (PI / 4.0))) % 8
	return "AIRPORT %dm %s" % [int(round(dist)), dirs[idx]]


func _show_objective(text: String, secs := 3.5) -> void:
	hud.show_objective(text, secs)
