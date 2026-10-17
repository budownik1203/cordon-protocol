class_name Fauna
extends CharacterBody2D
## Skażeniec: szybka fauna atakująca wręcz. Reaguje na hałas, goni gracza po nawigacji siatkowej.

signal died_signal

var nav: GridNav
var player: Player
var hp: float = 55.0
var alive: bool = true
var speed: float = 105.0
var bite_damage: float = 17.0
var _path: PackedVector2Array = PackedVector2Array()
var _repath: float = 0.0
var _bite_cd: float = 0.0
var _target: Vector2 = Vector2.ZERO
var _hunting: bool = false
var _flash: float = 0.0
var _wander_t: float = 0.0
var _anim_t: float = 0.0
var _screeched: bool = false


func setup(p_nav: GridNav, p_player: Player) -> void:
	nav = p_nav
	player = p_player


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)
	Events.noise.connect(_on_noise)
	# fauna zaczyna od wyczucia gracza w zasięgu zapachu
	_hunting = false


func _on_noise(pos: Vector2, radius: float, source: Node) -> void:
	if not alive or source == self:
		return
	if global_position.distance_to(pos) <= radius * 1.2:
		_start_hunt()
		_target = pos
		_repath = 0.0


func _start_hunt() -> void:
	_hunting = true
	if not _screeched:
		_screeched = true
		Audio.play_at("fauna_screech", global_position, -2.0, randf_range(0.85, 1.15), 650.0)


func take_hit(dmg: float, dir: Vector2, _pen: int = 2) -> void:
	if not alive:
		return
	hp -= dmg
	_flash = 0.1
	_start_hunt()
	FxLayer.spawn(self, global_position, "goo", dir, 8)
	Audio.play_at("hit_flesh", global_position, -4.0, 0.8, 500.0)
	if hp <= 0.0:
		alive = false
		collision_layer = 0
		Audio.play_at("fauna_die", global_position, -2.0, 1.0, 600.0)
		died_signal.emit()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not alive:
		return
	_flash = maxf(0.0, _flash - delta)
	_bite_cd = maxf(0.0, _bite_cd - delta)
	if player and player.is_alive() and _can_smell():
		_start_hunt()
		_target = player.global_position
	if _hunting:
		_repath -= delta
		if _repath <= 0.0:
			_repath = 0.4
			_path = nav.find_path(global_position, _target)
			if _path.size() > 0:
				_path.remove_at(0)
		if _path.is_empty():
			velocity = Vector2.ZERO
			if global_position.distance_to(_target) < 24.0 and not (player and player.is_alive() and _can_smell()):
				_hunting = false
		else:
			var t := _path[0]
			if global_position.distance_to(t) < 4.0:
				_path.remove_at(0)
			else:
				velocity = (t - global_position).normalized() * speed
				move_and_slide()
	if player and player.is_alive() and global_position.distance_to(player.global_position) < 16.0 and _bite_cd <= 0.0:
		_bite_cd = 0.9
		Audio.play_at("bite", global_position, 0.0, 1.0, 500.0)
		player.take_hit(bite_damage, (player.global_position - global_position).normalized(), 1, "fauna")
	queue_redraw()
	_anim_t += delta * velocity.length() / 14.0
	visible = player == null or player.can_see_point(global_position) or not alive


func _can_smell() -> bool:
	return global_position.distance_to(player.global_position) < 150.0 \
		and nav.has_los(global_position, player.global_position)


func _draw() -> void:
	if not alive:
		return
	var tex: Texture2D = Assets.tex("fauna")
	if tex == null:
		draw_circle(Vector2.ZERO, 6.0, Color(1, 1, 1) if _flash > 0.0 else Color(0.55, 0.2, 0.55))
		return
	var dir := velocity if velocity.length() > 5.0 else (player.global_position - global_position if player else Vector2.RIGHT)
	var frame := 0
	if velocity.length() > 5.0:
		frame = 1 + int(_anim_t) % 2
	draw_set_transform(Vector2.ZERO, dir.angle(), Vector2.ONE)
	draw_texture_rect_region(tex, Rect2(-8, -8, 16, 16), Rect2(frame * 16, 0, 16, 16))
	if _flash > 0.0:
		draw_circle(Vector2.ZERO, 7.0, Color(1, 1, 1, 0.55))
	draw_set_transform_matrix(Transform2D.IDENTITY)
