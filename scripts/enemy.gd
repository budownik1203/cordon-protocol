class_name Enemy
extends CharacterBody2D
## Wróg taktyczny: widzi stożkiem, słyszy strzały, korzysta z osłon, flankuje na rozkaz grupy.

signal killed(enemy: Enemy)

enum State { IDLE, ADVANCE, TO_COVER, IN_COVER, PEEK, FLANK }

const FACTIONS := {
	"Szabrownicy": {"color": Color(0.72, 0.52, 0.22), "damage": 15.0, "pen": 2, "rpm": 300.0, "spread": 4.5,
		"speed": 66.0, "reaction": 0.6, "range": 200.0, "vest": 0, "helmet": 0},
	"Najemnicy": {"color": Color(0.7, 0.25, 0.4), "damage": 22.0, "pen": 3, "rpm": 480.0, "spread": 2.6,
		"speed": 76.0, "reaction": 0.4, "range": 250.0, "vest": 3, "helmet": 2},
	"Wojskowi": {"color": Color(0.35, 0.6, 0.35), "damage": 27.0, "pen": 3, "rpm": 420.0, "spread": 2.2,
		"speed": 72.0, "reaction": 0.35, "range": 270.0, "vest": 4, "helmet": 3},
}
const TRAITS := ["ostrożny", "agresywny", "tchórzliwy"]

const STATE_NAMES := ["idle", "advance", "to_cover", "in_cover", "peek", "flank"]

@export var faction: String = "Najemnicy"
@export var move_speed: float = 70.0
@export var sight_range: float = 260.0
@export var fov_deg: float = 110.0
@export var fire_range: float = 230.0
@export var damage: float = 14.0
@export var penetration: int = 2
@export var rpm: float = 420.0
@export var base_spread_deg: float = 3.0
@export var reaction_time: float = 0.45
@export var memory_time: float = 6.0

var nav: GridNav
var player: Player
var group: GroupManager
var body: Body
var role: String = ""
var state: int = State.IDLE
var facing: Vector2 = Vector2.RIGHT

var last_known: Vector2 = Vector2.ZERO
var has_target: bool = false
var sees_player: bool = false

var _fx: Node2D
var _path: PackedVector2Array = PackedVector2Array()
var _memory: float = 0.0
var _seen_time: float = 0.0
var _think_t: float = 0.0
var _state_t: float = 0.0
var _fire_cd: float = 0.0
var _burst_left: int = 0
var _cover_cell: Vector2i = Vector2i.ZERO
var _peek_cell: Vector2i = Vector2i.ZERO
var _flash: float = 0.0
var trait_name: String = "ostrożny"
var weak_threshold: float = 0.4
var wait_mult: float = 1.0
var base_color: Color = Color(0.8, 0.3, 0.25)
var elite: bool = false
var _anim_t: float = 0.0

const SPRITES := {"Szabrownicy": "szab", "Najemnicy": "najem", "Wojskowi": "wojsk"}
const VOICE := {"Szabrownicy": "a", "Najemnicy": "b", "Wojskowi": "c"}
static var _last_alert_ms: int = -100000


func setup(p_nav: GridNav, p_player: Player, fx: Node2D) -> void:
	nav = p_nav
	player = p_player
	_fx = fx


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)
	body = Body.new()
	configure(faction)
	body.died.connect(func(_c): killed.emit(self))
	Events.noise.connect(_on_noise)


## Ustawia parametry frakcji i losową cechę charakteru.
func configure(f: String) -> void:
	faction = f
	var cfg: Dictionary = FACTIONS.get(f, FACTIONS["Najemnicy"])
	base_color = cfg["color"]
	damage = cfg["damage"]
	penetration = cfg["pen"]
	rpm = cfg["rpm"]
	base_spread_deg = cfg["spread"]
	move_speed = cfg["speed"]
	reaction_time = cfg["reaction"]
	fire_range = cfg["range"]
	body.vest = ArmorData.make("Kamizelka", cfg["vest"], 50.0) if cfg["vest"] > 0 else null
	body.helmet = ArmorData.make("Hełm", cfg["helmet"], 40.0) if cfg["helmet"] > 0 and randf() < 0.6 else null
	trait_name = TRAITS[randi() % TRAITS.size()]
	if elite:
		damage = 30.0
		penetration = 3
		rpm = 500.0
		base_spread_deg = 1.8
		move_speed = 70.0
		reaction_time = 0.3
		fire_range = 290.0
		body.vest = ArmorData.make("Kamizelka kl. 5", 5, 120.0)
		body.helmet = ArmorData.make("Hełm kl. 4", 4, 60.0)
		if trait_name == "tchórzliwy":
			trait_name = "ostrożny"
	match trait_name:
		"ostrożny":
			wait_mult = 1.5
		"agresywny":
			wait_mult = 0.5
			reaction_time *= 0.8
		"tchórzliwy":
			weak_threshold = 0.65


func is_engaged() -> bool:
	return has_target and body.alive


func state_name() -> String:
	return STATE_NAMES[state]


func take_hit(dmg: float, dir: Vector2, pen: int = 2) -> void:
	if not body.alive:
		return
	var was_alive := body.alive
	var part := body.pick_part()
	var dealt := body.apply_hit(part, dmg, pen)
	_flash = 0.12
	if dealt < dmg * 0.85 and body.vest != null and part in [Body.Part.CHEST, Body.Part.STOMACH, Body.Part.HEAD]:
		Audio.play_at("hit_armor", global_position, -4.0, 1.0, 500.0)
		FxLayer.spawn(self, global_position, "spark", dir, 6)
	else:
		Audio.play_at("hit_flesh", global_position, -4.0, 1.0, 500.0)
		FxLayer.spawn(self, global_position, "blood", dir, 8)
	# wróg trafiony wie, skąd strzelano
	if player and body.alive:
		_alert(player.global_position, true)
	if was_alive and not body.alive:
		Audio.play_at("die_enemy", global_position, -2.0, 1.0, 600.0)
	if not body.alive:
		_path = PackedVector2Array()
		velocity = Vector2.ZERO
		collision_layer = 0
	queue_redraw()


func receive_radio(pos: Vector2) -> void:
	if not body.alive:
		return
	_alert(pos, false)


func _on_noise(pos: Vector2, radius: float, source: Node) -> void:
	if not body.alive or source == self:
		return
	if global_position.distance_to(pos) <= radius:
		_alert(pos, false)


func _alert(pos: Vector2, share: bool) -> void:
	if not has_target:
		_seen_time = 0.0
		Audio.play_at("bark_" + VOICE.get(faction, "b"), global_position, -2.0, 1.0, 650.0)
		var now := Time.get_ticks_msec()
		if now - _last_alert_ms > 7000:
			_last_alert_ms = now
			Audio.play("alert", -8.0, 1.0, 0.0)
	has_target = true
	_memory = memory_time
	last_known = pos
	if share and group:
		group.report(self, pos)


func _physics_process(delta: float) -> void:
	if not body.alive:
		body.tick(delta)
		return
	body.tick(delta)
	_flash = maxf(0.0, _flash - delta)
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_state_t += delta
	_think_t -= delta
	if _think_t <= 0.0:
		_think_t = 0.15
		_think()
	_follow_path(delta)
	visible = player == null or player.can_see_point(global_position)
	queue_redraw()


func _can_see_player() -> bool:
	if player == null or not player.is_alive():
		return false
	var to_p := player.global_position - global_position
	if to_p.length() > sight_range:
		return false
	if absf(rad_to_deg(facing.angle_to(to_p))) > fov_deg * 0.5 and to_p.length() > 40.0:
		return false
	return nav.has_los(global_position, player.global_position)


func _think() -> void:
	sees_player = _can_see_player()
	if sees_player:
		if not has_target:
			_seen_time = 0.0
		_seen_time += 0.15
		has_target = true
		_memory = memory_time
		var first := last_known == Vector2.ZERO or last_known.distance_to(player.global_position) > 1.0
		last_known = player.global_position
		if group and first:
			group.report(self, last_known)
	elif has_target:
		_memory -= 0.15
		if _memory <= 0.0:
			has_target = false
			role = ""
			_set_state(State.IDLE)
			return
	if not has_target:
		return

	var weak := body.total_frac() < weak_threshold
	match state:
		State.IDLE:
			_set_state(State.ADVANCE if not sees_player else _combat_state(weak))
		State.ADVANCE:
			if sees_player:
				_set_state(_combat_state(weak))
			elif _path.is_empty():
				_goto(last_known)
		State.TO_COVER:
			if _path.is_empty():
				_set_state(State.IN_COVER)
		State.IN_COVER:
			facing = (last_known - global_position).normalized()
			var wait := 3.0 if weak else randf_range(1.0, 2.0) * wait_mult
			if _state_t > wait and not weak:
				_set_state(State.PEEK)
		State.PEEK:
			if _path.is_empty() and sees_player:
				_shoot_logic()
			if _state_t > 2.4 or (_path.is_empty() and not sees_player and _state_t > 0.8):
				_set_state(State.TO_COVER)
		State.FLANK:
			if _path.is_empty() or sees_player:
				if sees_player:
					_shoot_logic()
				if _path.is_empty() and _state_t > 0.5:
					# dotarł na flankę – dalej walczy jako strzelec w osłonie
					role = "suppress"
					_set_state(State.TO_COVER)


func _combat_state(weak: bool) -> int:
	if role == "flank" and not weak:
		return State.FLANK
	return State.TO_COVER


func _set_state(s: int) -> void:
	state = s
	_state_t = 0.0
	match s:
		State.ADVANCE:
			_goto(last_known)
		State.TO_COVER:
			_pick_cover()
		State.IN_COVER:
			_path = PackedVector2Array()
		State.PEEK:
			_goto(nav.center(_peek_cell))
		State.FLANK:
			_pick_flank()
		State.IDLE:
			_path = PackedVector2Array()


## Szuka komórki bez widoku na ostatnią pozycję gracza, z sąsiadem, z którego widać gracza.
func _pick_cover() -> void:
	var best := Vector2i(-1, -1)
	var best_peek := Vector2i(-1, -1)
	var best_score := -1e9
	for c in nav.free_cells_near(global_position, 7):
		var pos := nav.center(c)
		if nav.has_los(pos, last_known):
			continue
		var peek := _find_peek(c)
		if peek.x < 0:
			continue
		var score := -pos.distance_to(global_position) * 0.6 \
			- absf(pos.distance_to(last_known) - fire_range * 0.6) * 0.3
		if score > best_score:
			best_score = score
			best = c
			best_peek = peek
	if best.x < 0:
		# brak osłony – walcz z miejsca
		_cover_cell = nav.to_cell(global_position)
		_peek_cell = _cover_cell
		_path = PackedVector2Array()
		return
	_cover_cell = best
	_peek_cell = best_peek
	_goto(nav.center(best))


func _find_peek(cover: Vector2i) -> Vector2i:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
			Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var n: Vector2i = cover + d
		if not nav.is_solid(n) and nav.has_los(nav.center(n), last_known):
			return n
	return Vector2i(-1, -1)


## Flankowanie: punkt z boku od linii wróg–gracz, z którego widać gracza.
func _pick_flank() -> void:
	var to_p := (last_known - global_position)
	var side := Vector2(-to_p.y, to_p.x).normalized()
	var best := Vector2(-1, -1)
	var best_len := 1e9
	for sgn in [1.0, -1.0]:
		for dist in [110.0, 150.0, 190.0]:
			var pos: Vector2 = last_known + side * sgn * dist
			var c := nav.to_cell(pos)
			if nav.is_solid(c):
				continue
			var p := nav.find_path(global_position, nav.center(c))
			if p.is_empty():
				continue
			if not nav.has_los(nav.center(c), last_known):
				continue
			var len_ := 0.0
			for i in range(1, p.size()):
				len_ += p[i - 1].distance_to(p[i])
			if len_ < best_len:
				best_len = len_
				best = nav.center(c)
	if best.x < 0:
		role = "suppress"
		_set_state(State.TO_COVER)
		return
	_goto(best)


func _goto(pos: Vector2) -> void:
	_path = nav.find_path(global_position, pos)
	if _path.size() > 0:
		_path.remove_at(0)


func _follow_path(_delta: float) -> void:
	if _path.is_empty():
		velocity = Vector2.ZERO
		if sees_player and player:
			facing = (player.global_position - global_position).normalized()
		return
	var target := _path[0]
	var to_t := target - global_position
	if to_t.length() < 3.0:
		_path.remove_at(0)
		return
	var dir := to_t.normalized()
	facing = facing.lerp(dir, 0.25).normalized()
	velocity = dir * move_speed * body.speed_mult()
	move_and_slide()


func _shoot_logic() -> void:
	if not sees_player or _seen_time < reaction_time:
		return
	if global_position.distance_to(player.global_position) > fire_range:
		return
	if _fire_cd > 0.0:
		return
	_shoot()


func _shoot() -> void:
	_fire_cd = 60.0 / rpm
	if _burst_left <= 0:
		_burst_left = randi_range(3, 6)
	_burst_left -= 1
	if _burst_left <= 0:
		_fire_cd += randf_range(0.5, 1.0)
	var to_p := (player.global_position - global_position).normalized()
	var spread := deg_to_rad(randf_range(-base_spread_deg, base_spread_deg) * (1.0 + 0.5 * pain_factor()))
	var dir := to_p.rotated(spread)
	var from := global_position + to_p * 10.0
	var to := from + dir * fire_range * 1.4
	var q := PhysicsRayQueryParameters2D.create(from, to, 1 | 2, [get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	var end := to
	if hit:
		end = hit.position
		var c: Object = hit.collider
		if c and c.has_method("take_hit"):
			c.take_hit(damage, dir, penetration, faction)
	Events.emit_noise(global_position, 260.0, self)
	Audio.play_at("shot_enemy_" + VOICE.get(faction, "b"), global_position, -1.0, 1.0, 800.0)
	FxLayer.spawn(self, from, "muzzle", dir, 3)
	if _fx and _fx.has_method("add_trace"):
		_fx.add_trace(from, end, Color(1.0, 0.45, 0.35))


func pain_factor() -> float:
	return body.pain + (1.0 - body.arms_frac())


func _draw() -> void:
	if body and not body.alive:
		return
	var sprite: String = "elita" if elite else SPRITES.get(faction, "najem")
	var tex: Texture2D = Assets.tex(sprite)
	if tex == null:
		draw_circle(Vector2.ZERO, 6.0, base_color)
		draw_line(Vector2.ZERO, facing * 12.0, Color(0.95, 0.95, 0.95), 2.0)
	else:
		var frame := 0
		if velocity.length() > 5.0:
			frame = 1 + int(_anim_t) % 2
		var k := 1.2 if elite else 1.0
		draw_set_transform(Vector2.ZERO, facing.angle(), Vector2(k, k))
		draw_texture_rect_region(tex, Rect2(-8, -8, 16, 16), Rect2(frame * 16, 0, 16, 16))
		if _flash > 0.0:
			draw_circle(Vector2.ZERO, 7.0, Color(1, 1, 1, 0.55))
		draw_set_transform_matrix(Transform2D.IDENTITY)
	if body and body.alive and has_target:
		draw_circle(Vector2(0, -11), 2.0, Color(1.0, 0.8, 0.2) if sees_player else Color(0.9, 0.5, 0.1))
