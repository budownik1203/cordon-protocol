class_name Enemy3D
extends CharacterBody3D
## Wróg 3D: stoi / patroluje, widzi gracza w stożku i na siatce, szuka drogi A*, strzela seriami.
## Ciało z tego samego modelu obrażeń co w 2D (7 części, śmierć: głowa lub klatka).

enum State { IDLE, COMBAT, SEARCH }

const FACTIONS := {
	"szabrownicy": {"cloth": Color(0.45, 0.36, 0.26), "vest": Color(0.3, 0.26, 0.2), "helm": Color(0.4, 0.33, 0.25),
		"vest_on": false, "helm_on": false, "dmg": 9.0, "speed": 2.4, "acc": 5.5},
	"najemnicy": {"cloth": Color(0.16, 0.17, 0.2), "vest": Color(0.1, 0.1, 0.13), "helm": Color(0.12, 0.12, 0.15),
		"vest_on": true, "helm_on": true, "dmg": 14.0, "speed": 2.9, "acc": 3.2},
	"wojskowi": {"cloth": Color(0.25, 0.32, 0.22), "vest": Color(0.2, 0.26, 0.17), "helm": Color(0.22, 0.3, 0.2),
		"vest_on": true, "helm_on": true, "dmg": 18.0, "speed": 2.7, "acc": 2.6},
}

var faction: String = "szabrownicy"
var body: Body = Body.new()
var figure: LowPolyFigure
var player: Player3D
var nav: GridNav
var state: int = State.IDLE
var yaw: float = 0.0
var last_seen := Vector3.ZERO
var alert_t: float = 0.0

var _cfg: Dictionary
var _cooldown: float = 1.0
var _burst: int = 0
var _path: PackedVector2Array = PackedVector2Array()
var _path_i: int = 0
var _repath_t: float = 0.0
var _idle_t: float = 0.0
var _idle_yaw: float = 0.0
var _strafe: float = 1.0
var _dead_t: float = 0.0
var _dead: bool = false


func setup(p_faction: String, p_player: Player3D, p_nav: GridNav) -> void:
	faction = p_faction
	player = p_player
	nav = p_nav
	_cfg = FACTIONS[faction]
	if _cfg["vest_on"]:
		body.vest = ArmorData.make("Kamizelka", 3 if faction == "wojskowi" else 2, 50.0)
	if _cfg["helm_on"]:
		body.helmet = ArmorData.make("Hełm", 2, 40.0)


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.87
	add_child(cs)
	figure = LowPolyFigure.new()
	add_child(figure)
	figure.build(Color(0.8, 0.62, 0.5), _cfg["cloth"], _cfg["vest"], _cfg["helm"], _cfg["vest_on"], _cfg["helm_on"], Color(0.12, 0.12, 0.13))
	yaw = randf() * TAU
	_idle_yaw = yaw
	body.died.connect(_die)
	_strafe = 1.0 if randf() < 0.5 else -1.0


func px(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z) * 32.0


func hear(pos: Vector3, radius: float) -> void:
	if _dead or state == State.COMBAT:
		return
	if global_position.distance_to(pos) < radius:
		last_seen = pos
		state = State.SEARCH
		alert_t = 10.0
		_path = PackedVector2Array()


func _can_see_player() -> bool:
	if player == null or not player.is_alive():
		return false
	var to := player.global_position - global_position
	var d := to.length()
	if d > 22.0:
		return false
	if d > 3.0:
		var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
		if absf(rad_to_deg(fwd.angle_to(Vector3(to.x, 0, to.z)))) > 62.0 and state != State.COMBAT:
			return false
	return nav.has_los(px(global_position), px(player.global_position))


func _physics_process(delta: float) -> void:
	if _dead:
		_dead_t = minf(1.0, _dead_t + delta * 2.2)
		figure.rotation.x = -_dead_t * 1.5
		return
	body.tick(delta)
	if _dead:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	var sees := _can_see_player()
	var move_dir := Vector3.ZERO
	var speed: float = _cfg["speed"] * body.speed_mult()
	if sees:
		state = State.COMBAT
		last_seen = player.global_position
		alert_t = 6.0
	elif state == State.COMBAT:
		alert_t -= delta
		if alert_t <= 0.0:
			state = State.SEARCH
			alert_t = 8.0
			_path = PackedVector2Array()
	elif state == State.SEARCH:
		alert_t -= delta
		if alert_t <= 0.0:
			state = State.IDLE

	match state:
		State.COMBAT:
			var to := last_seen - global_position
			to.y = 0
			var d := to.length()
			_turn_to(to.normalized(), delta, 5.0)
			if sees and d < 12.0 and d > 6.5:
				move_dir = to.normalized().rotated(Vector3.UP, _strafe * 1.2) * 0.6  # krąży zamiast stać
				if randf() < 0.01:
					_strafe = -_strafe
			elif d >= 12.0 or not sees:
				move_dir = _follow_path(last_seen, delta)
			elif d <= 6.5:
				move_dir = -to.normalized() * 0.7
			if sees and _cooldown <= 0.0:
				_shoot()
		State.SEARCH:
			move_dir = _follow_path(last_seen, delta)
			if move_dir != Vector3.ZERO:
				_turn_to(move_dir.normalized(), delta, 3.0)
			else:
				_idle_look(delta)
		_:
			_idle_look(delta)
	var v := Vector2(velocity.x, velocity.z).move_toward(Vector2(move_dir.x, move_dir.z) * speed, 9.0 * delta)
	velocity = Vector3(v.x, 0, v.y)
	move_and_slide()
	global_position.y = 0.0
	figure.rotation.y = yaw
	figure.animate(delta, clampf(v.length() / 2.6, 0.0, 1.4), false)


func _idle_look(delta: float) -> void:
	_idle_t -= delta
	if _idle_t <= 0.0:
		_idle_t = randf_range(2.0, 5.0)
		_idle_yaw = yaw + randf_range(-1.6, 1.6)
	yaw = lerp_angle(yaw, _idle_yaw, 1.0 - exp(-delta * 1.5))


func _turn_to(dir: Vector3, delta: float, rate: float) -> void:
	if dir.length() < 0.01:
		return
	var want := atan2(-dir.x, -dir.z)
	yaw += clampf(angle_difference(yaw, want), -rate * delta, rate * delta)


func _follow_path(target: Vector3, delta: float) -> Vector3:
	_repath_t -= delta
	if _repath_t <= 0.0 or _path.is_empty():
		_repath_t = 0.5
		_path = nav.find_path(px(global_position), px(target))
		_path_i = 1
	if _path.is_empty() or _path_i >= _path.size():
		return Vector3.ZERO
	var wp := Vector3(_path[_path_i].x / 32.0, 0, _path[_path_i].y / 32.0)
	var to := wp - global_position
	to.y = 0
	if to.length() < 0.5:
		_path_i += 1
		return Vector3.ZERO
	return to.normalized()


func _shoot() -> void:
	if _burst <= 0:
		_burst = randi_range(2, 4)
	_burst -= 1
	_cooldown = 0.16 if _burst > 0 else randf_range(0.8, 1.5)
	var to := player.global_position + Vector3(0, 1.1, 0) - (global_position + Vector3(0, 1.3, 0))
	var d := to.length()
	var spread: float = _cfg["acc"] + d * 0.15
	var dir := to.normalized().rotated(Vector3.UP, deg_to_rad(randf_range(-spread, spread)))
	var from := global_position + Vector3(0, 1.3, 0) + dir * 0.8
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 40.0, 1 | 2, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end := from + dir * 40.0
	if not hit.is_empty():
		end = hit["position"]
		var col: Object = hit["collider"]
		if col == player:
			player.take_hit(_cfg["dmg"], dir, 2)
		else:
			Fx3D.burst(get_parent(), end, hit["normal"], Color(1, 0.8, 0.4), 4, 2.5)
	Fx3D.tracer(get_parent(), from, end, Color(1.0, 0.55, 0.3))
	Fx3D.flash(get_parent(), from, Color(1.0, 0.6, 0.3))
	figure.recoil = 1.0
	Audio.play("shot_enemy_a" if faction == "szabrownicy" else ("shot_enemy_b" if faction == "najemnicy" else "shot_enemy_c"), -9.0, 1.0, 0.05)


func take_hit(damage: float, dir: Vector3, pen: int = 2, hit_y: float = -1.0) -> void:
	if _dead:
		return
	var part := body.pick_part()
	if hit_y >= 0.0:
		# w widoku FPS wysokość trafienia decyduje o części ciała
		if hit_y > 1.5:
			part = Body.Part.HEAD
		elif hit_y > 1.05:
			part = Body.Part.CHEST if randf() < 0.75 else (Body.Part.L_ARM if randf() < 0.5 else Body.Part.R_ARM)
		elif hit_y > 0.8:
			part = Body.Part.STOMACH
		else:
			part = Body.Part.L_LEG if randf() < 0.5 else Body.Part.R_LEG
	body.apply_hit(part, damage, pen)
	Fx3D.burst(get_parent(), global_position + Vector3(0, 1.2, 0), -dir, Color(0.65, 0.05, 0.05), 8, 3.0)
	Audio.play("hit_flesh", -6.0, 1.0, 0.05)
	if not _dead:
		state = State.COMBAT
		last_seen = player.global_position
		alert_t = 8.0


func _die(_cause: String) -> void:
	_dead = true
	collision_layer = 0
	var tw := create_tween()
	tw.tween_interval(0.0)
