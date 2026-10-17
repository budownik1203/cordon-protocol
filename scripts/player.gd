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
		return weapon_item.loaded if weapon_item else 0
	set(v):
		if weapon_item:
			weapon_item.loaded = v


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


func reserve_ammo() -> int:
	if weapon_item == null:
		return 0
	return equipment.count_of(_ammo_id())


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

	if reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			reloading = false
			_finish_reload()
	else:
		if Input.is_action_just_pressed("reload") and not input_locked and ammo < weapon.magazine_size and reserve_ammo() > 0:
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
	reloading = true
	var t := weapon.reload_time * body.reload_mult()
	var has_quick := false
	for e in equipment.bags():
		if e["quick"] and e["bag"].count_of(_ammo_id()) > 0:
			has_quick = true
	if not has_quick:
		t += 1.2  # amunicja w plecaku
	_reload_left = t
	Audio.play("reload_start", -4.0)
	ammo_changed.emit(ammo, weapon.magazine_size, true)


func _finish_reload() -> void:
	if weapon_item == null:
		return
	var need := weapon.magazine_size - weapon_item.loaded
	var got: int = equipment.take(_ammo_id(), need)[0]
	weapon_item.loaded += got
	Audio.play("reload_end", -3.0)
	ammo_changed.emit(ammo, weapon.magazine_size, false)


func _fire() -> void:
	if weapon_item.loaded <= 0:
		if reserve_ammo() > 0:
			_start_reload()
		else:
			Audio.play("empty_click", -4.0)
		_cooldown = 0.25
		return
	weapon_item.loaded -= 1
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
