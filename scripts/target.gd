class_name Target
extends StaticBody2D
## Manekin treningowy: ma punkty życia, błyska po trafieniu, potem się odnawia.

var max_hp := 100.0
var hp := 100.0
var _flash := 0.0
var _respawn := 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	add_child(shape)


func take_hit(damage: float, _dir: Vector2, _penetration: int = 2) -> void:
	if hp <= 0.0:
		return
	hp -= damage
	_flash = 0.12
	if hp <= 0.0:
		_respawn = 3.0
	queue_redraw()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		queue_redraw()
	if hp <= 0.0:
		_respawn -= delta
		if _respawn <= 0.0:
			hp = max_hp
			queue_redraw()


func _draw() -> void:
	if hp <= 0.0:
		draw_circle(Vector2.ZERO, 8.0, Color(0.25, 0.25, 0.25, 0.5))
		return
	var col := Color(0.9, 0.9, 0.9) if _flash > 0.0 else Color(0.75, 0.3, 0.25)
	draw_circle(Vector2.ZERO, 8.0, col)
	var frac := hp / max_hp
	draw_rect(Rect2(-8, -14, 16.0 * frac, 2), Color(0.3, 0.8, 0.3))
