class_name Player
extends CharacterBody2D
## Gracz: ruch, sprint, celowanie, strzał hitscan, ciało z ranami, leczenie z ekwipunku.

signal ammo_changed(in_mag: int, mag_size: int, reloading: bool)
signal died(cause: String)

const WALK_SPEED := 90.0
const CROUCH_SPEED := 45.0
const SPRINT_MULT := 1.6
const ACCEL := 700.0
const FRICTION := 900.0
const MUZZLE_OFFSET := 12.0
const FOV_DEG := 110.0
const SIGHT_RANGE := 300.0
const NEAR_SIGHT := 36.0

var equipment: Equipment
var weapon: WeaponData
var weapon_item: Item
var weapon_slot: String = "primary"
var body: Body
var reloading: bool = false
var reload_kind: String = ""  # "swap" (wymiana magazynka) | "feed" (ręczne dobijanie nabojów)
var loading_mags: bool = false  # trwa pakowanie luźnej amunicji do magazynków (C)
var crouching: bool = false
var sprinting: bool = false
var stamina: float = 100.0
var using_item: String = ""
var input_locked: bool = false  # np. otwarty ekwipunek
var sight_nav: GridNav
var kills: Dictionary = {}
var last_hit_source: String = ""

var _cooldown: float = 0.0
var _reload_left: float = 0.0
var _reload_total: float = 0.0
var _reload_src: Dictionary = {}
var _feed_t: float = 0.0
var _combine_t: float = 0.0
const FEED_TIME := 0.3  # sekundy na jeden nabój przy ręcznym ładowaniu
const COMBINE_TIME := 0.09  # sekundy na jeden nabój przy pakowaniu magazynków
var _use_left: float = 0.0
var _use_extra: float = 0.0
var _recoil_deg: float = 0.0
var _aim_dir: Vector2 = Vector2.RIGHT
var _fx: Node2D
var _sprint_noise_t: float = 0.0
var _anim_t: float = 0.0
var _step_dist: float = 0.0
var _heart_t: float = 0.0

## Zgodność z testami: liczba naboi w magazynku aktualnej broni.
var ammo: int:
	get:
		return weapon_item.rounds() if weapon_item else 0
	set(v):
		if weapon_item and weapon_item.mag:
			weapon_item.mag.loaded = v


func setup(p_equipment: Equipment) -> void:
	equipment = p_equipment
	_select_weapon("primary" if equipment.get_slot("primary") else "pistol")
	_sync_armor()


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)
	body = Body.new()
	body.died.connect(func(c): died.emit(c))
	if equipment == null:
		setup(Equipment.new())


func set_fx_layer(fx: Node2D) -> void:
	_fx = fx


func is_alive() -> bool:
	return body.alive


func _select_weapon(slot: String) -> void:
	weapon_slot = slot
	weapon_item = equipment.get_slot(slot)
	reloading = false
	reload_kind = ""
	loading_mags = false
	if weapon_item == null:
		weapon = null
		return
	var wd: Dictionary = weapon_item.def().get("weapon", {})
	weapon = WeaponData.new()
	weapon.display_name = wd.get("name", "Broń")
	weapon.damage = wd.get("damage", 20.0)
	weapon.rounds_per_minute = wd.get("rpm", 500.0)
	weapon.magazine_size = wd.get("mag", 30)
	weapon.reload_time = wd.get("reload", 2.0)
	weapon.base_spread_deg = wd.get("spread", 1.0)
	weapon.move_spread_deg = wd.get("move_spread", 4.0)
	weapon.recoil_per_shot_deg = wd.get("recoil", 0.9)
	weapon.recoil_recovery_deg = wd.get("recovery", 6.0)
	weapon.max_range = wd.get("range", 500.0)
	weapon.noise_radius = wd.get("noise", 300.0)
	weapon.sound = wd.get("snd", "shot_rifle")
	var ammo_id := _ammo_id()
	weapon.penetration = ItemDB.get_def(ammo_id).get("pen", 2)
	ammo_changed.emit(ammo, weapon.magazine_size, false)


func _ammo_id() -> String:
	if weapon_item == null:
		return ""
	return "ammo_" + String(weapon_item.def().get("ammo_type", ""))


func _mag_id() -> String:
	if weapon_item == null:
		return ""
	return String(weapon_item.def().get("mag_id", ""))


## Luźna amunicja pasująca do broni.
func loose_ammo() -> int:
	return equipment.count_of(_ammo_id()) if weapon_item else 0


## Zapasowe magazynki do aktualnej broni, od najpełniejszego (szybkie kieszenie wygrywają remisy).
func spare_mags() -> Array:
	var out := equipment.find_mags(_mag_id()) if weapon_item else []
	out.sort_custom(func(a, b):
		if a["item"].loaded != b["item"].loaded:
			return a["item"].loaded > b["item"].loaded
		return a["quick"] and not b["quick"])
	return out


func spare_rounds() -> int:
	var n := 0
	for m in spare_mags():
		n += m["item"].loaded
	return n


## Naboje dostępne poza magazynkiem w broni (do HUD i testów).
func reserve_ammo() -> int:
	return spare_rounds() + loose_ammo()


## Najlepszy zapasowy magazynek, który faktycznie coś daje (więcej nabojów niż obecny).
func best_spare() -> Dictionary:
	var cur := ammo
	for m in spare_mags():
		if m["item"].loaded > cur:
			return m
	return {}


func can_reload() -> bool:
	if weapon_item == null:
		return false
	if not best_spare().is_empty():
		return true
	return weapon_item.mag != null and ammo < weapon_item.mag.mag_cap() and loose_ammo() > 0


## Przenosi pancerz z przedmiotów do modelu ciała (zużycie zapisywane z powrotem).
func _sync_armor() -> void:
	body.helmet = _armor_from(equipment.get_slot("head"))
	body.vest = _armor_from(equipment.get_slot("armor"))


func _armor_from(it: Item) -> ArmorData:
	if it == null:
		return null
	var a := ArmorData.make(it.item_name(), it.def().get("armor_class", 1), it.def().get("durability", 40.0))
	a.durability = it.durability
	return a


func writeback_armor() -> void:
	var h := equipment.get_slot("head")
	if h and body.helmet:
		h.durability = body.helmet.durability
	var v := equipment.get_slot("armor")
	if v and body.vest:
		v.durability = body.vest.durability


func equipment_changed() -> void:
	_sync_armor()
	_select_weapon(weapon_slot if equipment.get_slot(weapon_slot) else ("primary" if equipment.get_slot("primary") else "pistol"))


func current_spread_deg() -> float:
	if weapon == null:
		return 0.0
	var move_factor := clampf(velocity.length() / WALK_SPEED, 0.0, 1.0)
	var crouch_mult := 0.6 if crouching else 1.0
	return (weapon.base_spread_deg + weapon.move_spread_deg * move_factor + _recoil_deg) \
		* crouch_mult * body.spread_mult()


func can_see_point(p: Vector2) -> bool:
	var to_p := p - global_position
	var d := to_p.length()
	if d <= NEAR_SIGHT:
		return true
	if d > SIGHT_RANGE:
		return false
	if absf(rad_to_deg(_aim_dir.angle_to(to_p))) > FOV_DEG * 0.5:
		return false
	return sight_nav == null or sight_nav.has_los(global_position, p)


## Wywoływane przez wrogów. Część ciała losowana, bo widok z góry nie ma wysokości.
func take_hit(damage: float, _dir: Vector2, penetration: int = 2, source: String = "") -> void:
	if not body.alive:
		return
	last_hit_source = source
	var was_alive := body.alive
	body.apply_hit(body.pick_part(), damage, penetration)
	Audio.play("hurt", -3.0)
	FxLayer.spawn(self, global_position, "blood", _dir, 8)
	if was_alive and not body.alive:
		Audio.play("die_player", 0.0, 1.0, 0.0)
	if using_item != "":
		using_item = ""


func _physics_process(delta: float) -> void:
	body.tick(delta)
	if not body.alive:
		velocity = Vector2.ZERO
		return
	crouching = Input.is_action_pressed("crouch")
	_aim_dir = (get_global_mouse_position() - global_position).normalized()
	rotation = _aim_dir.angle()

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	sprinting = Input.is_action_pressed("sprint") and input != Vector2.ZERO and stamina > 5.0 \
		and not crouching and using_item == ""
	var speed := (CROUCH_SPEED if crouching else WALK_SPEED) * body.speed_mult() * equipment.speed_mult()
	if sprinting:
		speed *= SPRINT_MULT
		stamina = maxf(0.0, stamina - 22.0 * delta)
		_sprint_noise_t -= delta
		if _sprint_noise_t <= 0.0:
			_sprint_noise_t = 0.5
			Events.emit_noise(global_position, 150.0, self)
	else:
		stamina = minf(100.0, stamina + (14.0 if input == Vector2.ZERO else 8.0) * delta)
	if using_item != "":
		speed *= 0.4
	if input != Vector2.ZERO:
		velocity = velocity.move_toward(input * speed, ACCEL * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	move_and_slide()
	_update_audio_and_anim(delta, input)

	_recoil_deg = maxf(0.0, _recoil_deg - (weapon.recoil_recovery_deg if weapon else 6.0) * delta)
	_cooldown = maxf(0.0, _cooldown - delta)

	_handle_healing(delta)
	if using_item != "" or weapon == null:
		if Input.is_action_just_pressed("swap_weapon") and using_item == "":
			_swap_weapon()
		return

	if Input.is_action_just_pressed("swap_weapon"):
		_swap_weapon()
		return

	if loading_mags:
		_tick_combine(delta)
		return
	if reloading:
		if reload_kind == "feed":
			_tick_feed(delta)
		else:
			_reload_left -= delta
			if _reload_left <= 0.0:
				reloading = false
				_finish_reload()
	else:
		if Input.is_action_just_pressed("combine") and not input_locked:
			start_combine()
		elif Input.is_action_just_pressed("reload") and not input_locked and can_reload():
			_start_reload()
		elif Input.is_action_pressed("fire") and _cooldown <= 0.0 and not input_locked and not sprinting:
			_fire()


func _update_audio_and_anim(delta: float, input: Vector2) -> void:
	var spd := velocity.length()
	if spd > 5.0:
		_anim_t += delta * (spd / 18.0)
		_step_dist += spd * delta
		var stride := 17.0 if sprinting else 24.0
		if _step_dist >= stride and not crouching:
			_step_dist = 0.0
			Audio.step(-4.0 if sprinting else -9.0)
			if spd > 60.0 and not sprinting:
				Events.emit_noise(global_position, 48.0, self)
		elif crouching:
			_step_dist = 0.0
	if body.pain > 0.45 or body.blood < 55.0:
		_heart_t -= delta
		if _heart_t <= 0.0:
			_heart_t = 1.1 if body.blood > 35.0 else 0.75
			Audio.play("heartbeat", -8.0 + 6.0 * clampf(1.0 - body.blood / 100.0, 0.0, 1.0), 1.0, 0.0)
	queue_redraw()


func _swap_weapon() -> void:
	var other := "pistol" if weapon_slot == "primary" else "primary"
	if equipment.get_slot(other):
		_select_weapon(other)
		Audio.play("swap_weapon", -4.0)


func _handle_healing(delta: float) -> void:
	if using_item == "":
		if input_locked:
			return
		for item in ["bandage", "hemostatic", "splint", "painkiller"]:
			if Input.is_action_just_pressed("use_" + item) and equipment.count_of(item) > 0:
				using_item = item
				_use_left = ItemDB.get_def(item).get("use_time", 3.0)
				# przedmioty z plecaka wyciąga się dłużej niż z kamizelki, pasa i kieszeni
				var in_quick := false
				for e in equipment.bags():
					if e["quick"] and e["bag"].count_of(item) > 0:
						in_quick = true
				if not in_quick:
					_use_left += 1.5
				reloading = false
				Events.emit_noise(global_position, 120.0, self)
				break
	else:
		_use_left -= delta
		if _use_left <= 0.0:
			var ok := false
			match using_item:
				"bandage": ok = body.use_bandage()
				"hemostatic": ok = body.use_hemostatic()
				"splint": ok = body.use_splint()
				"painkiller": ok = body.use_painkiller()
			if ok:
				equipment.take(using_item, 1)
			using_item = ""


func _start_reload() -> void:
	var spare := best_spare()
	reloading = true
	_reload_src = spare
	if not spare.is_empty():
		reload_kind = "swap"
		var t := weapon.reload_time * body.reload_mult()
		# taktyczna wymiana (magazynek jeszcze coś ma) jest szybsza niż po opróżnieniu
		t *= 0.5 if ammo > 0 else 0.8
		if weapon_item.mag == null:
			t *= 0.8
		if not spare["quick"]:
			t += 1.0  # magazynek z plecaka
		_reload_left = t
		_reload_total = t
		Audio.play("reload_start", -4.0)
	else:
		reload_kind = "feed"
		_feed_t = FEED_TIME * body.reload_mult()
		_reload_total = 0.0
		Audio.play("reload_start", -8.0)
	ammo_changed.emit(ammo, weapon.magazine_size, true)


func _finish_reload() -> void:
	if weapon_item == null:
		return
	var m := _reload_src
	if m.is_empty() or not (m["bag"] as Bag).items.has(m["item"]):
		m = best_spare()
	if not m.is_empty():
		var sp: Item = m["item"]
		var b: Bag = m["bag"]
		var px := sp.x
		var py := sp.y
		var rot := sp.rotated
		b.remove(sp)
		var old := weapon_item.mag
		weapon_item.mag = sp
		if old != null:
			old.rotated = rot
			if not (b.fits(old, px, py) and b.place(old, px, py)):
				equipment.add_auto(old, true)
		Audio.play("reload_end", -3.0)
	_reload_src = {}
	ammo_changed.emit(ammo, weapon.magazine_size, false)


## Ręczne dobijanie nabojów do włożonego magazynka (gdy brak naładowanych zapasowych).
func _tick_feed(delta: float) -> void:
	var mg := weapon_item.mag
	if mg == null or loose_ammo() <= 0 or mg.loaded >= mg.mag_cap() or best_spare().size() > 0:
		reloading = false
		reload_kind = ""
		ammo_changed.emit(ammo, weapon.magazine_size, false)
		return
	if Input.is_action_just_pressed("fire") and ammo > 0 and not input_locked:
		reloading = false
		reload_kind = ""
		ammo_changed.emit(ammo, weapon.magazine_size, false)
		return
	_feed_t -= delta
	if _feed_t <= 0.0:
		_feed_t = FEED_TIME * body.reload_mult()
		if equipment.take(_ammo_id(), 1)[0] > 0:
			mg.loaded += 1
			Audio.play("ammo_tick", -8.0, 1.0 + 0.2 * float(mg.loaded) / maxf(1.0, mg.mag_cap()), 0.03)
			ammo_changed.emit(ammo, weapon.magazine_size, true)


## V: pakowanie luźnej amunicji do magazynków w ekwipunku (trwa, można przerwać strzałem lub ruchem biegu).
func start_combine() -> void:
	if reloading or loading_mags:
		return
	if not _has_combine_work():
		return
	loading_mags = true
	_combine_t = COMBINE_TIME
	Audio.play("reload_start", -10.0)


func _has_combine_work() -> bool:
	for e in equipment.bags():
		if e["slot"] == "secure":
			continue
		for it: Item in e["bag"].items:
			if it.is_mag() and it.loaded < it.mag_cap() and equipment.count_of(it.ammo_item_id()) > 0:
				return true
	return false


func _tick_combine(delta: float) -> void:
	if Input.is_action_just_pressed("fire") or Input.is_action_just_pressed("reload") or sprinting or input_locked:
		loading_mags = false
		return
	_combine_t -= delta
	if _combine_t <= 0.0:
		_combine_t = COMBINE_TIME
		var m := equipment.load_step()
		if m == null:
			loading_mags = false
			Audio.play("reload_end", -8.0)
		else:
			Audio.play("ammo_tick", -12.0, 0.9 + 0.3 * float(m.loaded) / maxf(1.0, m.mag_cap()), 0.03)


func _fire() -> void:
	if ammo <= 0:
		if can_reload():
			_start_reload()
		else:
			Audio.play("empty_click", -4.0)
		_cooldown = 0.25
		return
	weapon_item.mag.loaded -= 1
	_cooldown = weapon.seconds_per_shot()
	var spread := deg_to_rad(randf_range(-current_spread_deg(), current_spread_deg()))
	var dir := _aim_dir.rotated(spread)
	_recoil_deg += weapon.recoil_per_shot_deg
	ammo_changed.emit(ammo, weapon.magazine_size, false)
	Events.emit_noise(global_position, weapon.noise_radius, self)
	Audio.play(weapon.sound, -4.0, 1.0, 0.05)

	var from := global_position + _aim_dir * MUZZLE_OFFSET
	var to := from + dir * weapon.max_range
	var query := PhysicsRayQueryParameters2D.create(from, to, 1 | 4, [get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	var end := to
	if hit:
		end = hit.position
		var collider: Object = hit.collider
		if collider and collider.has_method("take_hit"):
			collider.take_hit(weapon.damage, dir, weapon.penetration)
			Audio.play("hit_confirm", -6.0, 1.0, 0.03)
		else:
			FxLayer.spawn(self, hit.position, "dust", -dir, 4)
			Audio.play_at("hit_wall", hit.position, -8.0, 1.0, 400.0)
	FxLayer.spawn(self, from, "muzzle", dir, 3)
	if _fx and _fx.has_method("add_trace"):
		_fx.add_trace(from, end)


func _draw() -> void:
	var alive_now := body == null or body.alive
	var tex: Texture2D = Assets.tex("player" if alive_now else "corpse_player")
	if tex == null:
		draw_circle(Vector2.ZERO, 6.0, Color(0.35, 0.6, 0.85) if alive_now else Color(0.3, 0.3, 0.3))
		draw_line(Vector2.ZERO, Vector2(12, 0), Color(0.9, 0.9, 0.9), 2.0)
		return
	if not alive_now:
		draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
		draw_texture_rect_region(tex, Rect2(-8, -8, 16, 16), Rect2(0, 0, 16, 16))
		return
	var frame := 0
	if velocity.length() > 5.0:
		frame = 1 + int(_anim_t) % 2
	if crouching:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.9, 0.9))
	draw_texture_rect_region(tex, Rect2(-8, -8, 16, 16), Rect2(frame * 16, 0, 16, 16))
