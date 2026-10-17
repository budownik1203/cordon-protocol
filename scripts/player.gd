class_name Player
extends CharacterBody2D
## Gracz: ruch 8-kierunkowy, celowanie myszą, strzał hitscan z rozrzutem.

signal ammo_changed(in_mag: int, mag_size: int, reloading: bool)

const WALK_SPEED := 90.0
const CROUCH_SPEED := 45.0
const ACCEL := 700.0
const FRICTION := 900.0
const MUZZLE_OFFSET := 12.0

var weapon: WeaponData
var ammo: int = 0
var reloading: bool = false
var crouching: bool = false

var _cooldown: float = 0.0
var _reload_left: float = 0.0
var _recoil_deg: float = 0.0
var _aim_dir: Vector2 = Vector2.RIGHT
var _fx: Node2D  # warstwa efektów (ślady strzałów)


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)
	weapon = WeaponData.new()
	ammo = weapon.magazine_size
	ammo_changed.emit(ammo, weapon.magazine_size, false)


func set_fx_layer(fx: Node2D) -> void:
	_fx = fx


func current_spread_deg() -> float:
	var move_factor := clampf(velocity.length() / WALK_SPEED, 0.0, 1.0)
	var crouch_mult := 0.6 if crouching else 1.0
	return (weapon.base_spread_deg + weapon.move_spread_deg * move_factor + _recoil_deg) * crouch_mult


func _physics_process(delta: float) -> void:
	crouching = Input.is_action_pressed("crouch")
	_aim_dir = (get_global_mouse_position() - global_position).normalized()
	rotation = _aim_dir.angle()

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed := CROUCH_SPEED if crouching else WALK_SPEED
	if input != Vector2.ZERO:
		velocity = velocity.move_toward(input * speed, ACCEL * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	move_and_slide()

	_recoil_deg = maxf(0.0, _recoil_deg - weapon.recoil_recovery_deg * delta)
	_cooldown = maxf(0.0, _cooldown - delta)

	if reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			reloading = false
			ammo = weapon.magazine_size
			ammo_changed.emit(ammo, weapon.magazine_size, false)
	else:
		if Input.is_action_just_pressed("reload") and ammo < weapon.magazine_size:
			_start_reload()
		elif Input.is_action_pressed("fire") and _cooldown <= 0.0:
			_fire()


func _start_reload() -> void:
	reloading = true
	_reload_left = weapon.reload_time
	ammo_changed.emit(ammo, weapon.magazine_size, true)


func _fire() -> void:
	if ammo <= 0:
		_start_reload()
		return
	ammo -= 1
	_cooldown = weapon.seconds_per_shot()
	var spread := deg_to_rad(randf_range(-current_spread_deg(), current_spread_deg()))
	var dir := _aim_dir.rotated(spread)
	_recoil_deg += weapon.recoil_per_shot_deg
	ammo_changed.emit(ammo, weapon.magazine_size, false)

	var from := global_position + _aim_dir * MUZZLE_OFFSET
	var to := from + dir * weapon.max_range
	var query := PhysicsRayQueryParameters2D.create(from, to, 1 | 4, [get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	var end := to
	if hit:
		end = hit.position
		var collider: Object = hit.collider
		if collider and collider.has_method("take_hit"):
			collider.take_hit(weapon.damage, dir)
	if _fx and _fx.has_method("add_trace"):
		_fx.add_trace(from, end)
