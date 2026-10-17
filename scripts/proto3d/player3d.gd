class_name Player3D
extends CharacterBody3D
## Gracz w 3D: ociężały ruch (inercja, wolny obrót tułowia), latarka ze światłem i cieniami,
## strzał hitscan, ciało z modelu obrażeń Body (to samo co w wersji 2D).

signal shot(pos: Vector3)
signal died(cause: String)
signal notice(text: String)

const WALK := 3.0
const CROUCH := 1.5
const SPRINT_MULT := 1.55
const ACCEL := 7.5
const FRICTION := 10.0
const BRAKE := 13.0
const TURN_RATE := 7.5
const TURN_RATE_SPRINT := 3.2
const MAG := 30
const FIRE_DELAY := 0.1

var body: Body = Body.new()
var cam: Camera3D
var figure: LowPolyFigure
var flash_light: SpotLight3D
var yaw: float = 0.0
var want_dir := Vector3(0, 0, -1)
var ammo: int = MAG
var reserve: int = 150
var reloading: bool = false
var sprinting: bool = false
var crouching: bool = false
var stamina: float = 100.0
var level_root: Node3D

var _reload_left: float = 0.0
var _cooldown: float = 0.0
var _recoil: float = 0.0
var _turn_vel: float = 0.0
var _sprint_t: float = 0.0
var _step_t: float = 0.0
var _dead_anim: float = 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)
	figure = LowPolyFigure.new()
	add_child(figure)
	figure.build(Color(0.85, 0.68, 0.55), Color(0.25, 0.3, 0.27), Color(0.2, 0.25, 0.35), Color(0.3, 0.36, 0.3), true, true, Color(0.18, 0.18, 0.2))
	flash_light = SpotLight3D.new()
	flash_light.position = Vector3(0.25, 1.45, -0.3)
	flash_light.rotation_degrees = Vector3(-9, 0, 0)
	flash_light.spot_angle = 36.0
	flash_light.spot_range = 24.0
	flash_light.light_energy = 9.0
	flash_light.spot_attenuation = 0.6
	flash_light.shadow_enabled = true
	flash_light.light_color = Color(1.0, 0.96, 0.85)
	figure.add_child(flash_light)
	var near := OmniLight3D.new()
	near.position = Vector3(0, 1.6, 0)
	near.omni_range = 5.5
	near.light_energy = 1.1
	near.light_color = Color(0.85, 0.9, 1.0)
	add_child(near)
	body.died.connect(func(c): _on_died(c))


func is_alive() -> bool:
	return body.alive


func _aim_point() -> Vector3:
	var vp := get_viewport()
	var mp := vp.get_mouse_position()
	var origin := cam.project_ray_origin(mp)
	var dir := cam.project_ray_normal(mp)
	var hit: Variant = Plane(Vector3.UP, 1.2).intersects_ray(origin, dir)
	return hit if hit != null else global_position + want_dir


func _physics_process(delta: float) -> void:
	body.tick(delta)
	if not body.alive:
		_dead_anim = minf(1.0, _dead_anim + delta * 2.5)
		figure.rotation.x = -_dead_anim * 1.45
		velocity = Vector3.ZERO
		return
	crouching = Input.is_key_pressed(KEY_C)
	if cam:
		var ap := _aim_point()
		var d := ap - global_position
		d.y = 0
		if d.length() > 0.2:
			want_dir = d.normalized()
	var load_k := 1.0
	var turn := (TURN_RATE_SPRINT if sprinting else TURN_RATE) * (0.6 + 0.4 * body.speed_mult())
	if crouching:
		turn *= 1.3
	var want_yaw := atan2(-want_dir.x, -want_dir.z)
	var diff := angle_difference(yaw, want_yaw)
	var step := clampf(diff, -turn * delta, turn * delta)
	_turn_vel = step / maxf(delta, 0.0001)
	yaw += step
	figure.rotation.y = yaw

	var input := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
	sprinting = Input.is_key_pressed(KEY_SHIFT) and input != Vector2.ZERO and stamina > 5.0 and not crouching and body.can_sprint()
	_sprint_t = move_toward(_sprint_t, 1.0 if sprinting else 0.0, delta / 0.75 * (1.0 if sprinting else 2.5))
	var ease_k := _sprint_t * _sprint_t * (3.0 - 2.0 * _sprint_t)
	var speed := (CROUCH if crouching else WALK) * body.speed_mult() * lerpf(1.0, SPRINT_MULT, ease_k)
	if sprinting:
		stamina = maxf(0.0, stamina - 22.0 * delta)
	else:
		stamina = minf(100.0, stamina + (14.0 if input == Vector2.ZERO else 8.0) * delta)
	var vel2 := Vector2(velocity.x, velocity.z)
	if input != Vector2.ZERO:
		var want := input.normalized() * speed
		var accel := ACCEL
		var dn := vel2.normalized()
		var opposing := maxf(0.0, -dn.dot(input.normalized())) if vel2.length() > 0.2 else 0.0
		if opposing > 0.0:
			accel += BRAKE * opposing
		else:
			accel *= 1.0 - 0.3 * absf(dn.cross(input.normalized()))
		vel2 = vel2.move_toward(want, accel * delta)
	else:
		vel2 = vel2.move_toward(Vector2.ZERO, FRICTION * delta)
	velocity = Vector3(vel2.x, 0, vel2.y)
	move_and_slide()
	global_position.y = 0.0

	var spd := vel2.length()
	figure.animate(delta, clampf(spd / WALK, 0.0, 1.6), sprinting)
	figure.torso_node.scale.y = 0.9 if crouching else 1.0
	if spd > 0.4 and not crouching:
		_step_t -= delta * spd
		if _step_t <= 0.0:
			_step_t = 1.35 if sprinting else 1.9
			Audio.step(-4.0 if sprinting else -9.0)

	_cooldown = maxf(0.0, _cooldown - delta)
	_recoil = maxf(0.0, _recoil - 6.0 * delta)
	if reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			reloading = false
			var need := MAG - ammo
			var got := mini(need, reserve)
			ammo += got
			reserve -= got
			Audio.play("reload_end", -3.0)
	else:
		if Input.is_action_just_pressed("reload") and ammo < MAG and reserve > 0:
			_start_reload()
		elif Input.is_action_pressed("fire") and _cooldown <= 0.0 and not sprinting:
			_fire()


func _start_reload() -> void:
	reloading = true
	_reload_left = 2.2 * body.reload_mult()
	Audio.play("reload_start", -4.0)


func _spread_deg() -> float:
	var move_f := clampf(Vector2(velocity.x, velocity.z).length() / WALK, 0.0, 1.0)
	var sway := minf(2.5, absf(_turn_vel) * 0.35)
	return (0.9 + 3.5 * move_f + _recoil + sway) * (0.6 if crouching else 1.0) * body.spread_mult()


func _fire() -> void:
	if ammo <= 0:
		if reserve > 0:
			_start_reload()
		else:
			Audio.play("empty_click", -4.0)
		_cooldown = 0.25
		return
	ammo -= 1
	_cooldown = FIRE_DELAY
	_recoil += 0.9
	figure.recoil = 1.0
	var sp := deg_to_rad(randf_range(-_spread_deg(), _spread_deg()))
	var dir := (-figure.global_transform.basis.z).rotated(Vector3.UP, sp)
	var from := global_position + Vector3(0, 1.3, 0) + dir * 0.8
	var to := from + dir * 60.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 4, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end := to
	if not hit.is_empty():
		end = hit["position"]
		var col: Object = hit["collider"]
		if col != null and col.has_method("take_hit"):
			col.take_hit(32.0, dir, 3)
		else:
			Fx3D.burst(get_parent(), end, hit["normal"], Color(1, 0.8, 0.4), 6, 3.0)
	Fx3D.tracer(get_parent(), from, end)
	Fx3D.flash(get_parent(), from)
	Audio.play("shot_rifle", -4.0, 1.0, 0.05)
	shot.emit(global_position)


func take_hit(damage: float, dir: Vector3, pen: int = 2) -> void:
	if not body.alive:
		return
	body.apply_hit(body.pick_part(), damage, pen)
	Audio.play("hurt", -3.0)
	Fx3D.burst(get_parent(), global_position + Vector3(0, 1.2, 0), -dir, Color(0.7, 0.05, 0.05), 8, 3.0)


func _on_died(cause: String) -> void:
	Audio.play("die_player", 0.0, 1.0, 0.0)
	flash_light.light_energy = 1.0
	died.emit(cause)
