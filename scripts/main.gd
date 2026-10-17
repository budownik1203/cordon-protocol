extends Node2D
## Prototyp 1: pokój testowy z manekinami. Poziom budowany z mapy ASCII.

const TILE := 32

const LEVEL := [
	"########################",
	"#......................#",
	"#......................#",
	"#..P............T......#",
	"#.......####...........#",
	"#.......#..............#",
	"#.......#.......T......#",
	"#..............####....#",
	"#..T...................#",
	"#......................#",
	"########################",
]

var player: Player


func _ready() -> void:
	var fx := Node2D.new()
	fx.set_script(load("res://scripts/fx_layer.gd"))
	fx.z_index = 10

	var spawn := Vector2(64, 64)
	for y in LEVEL.size():
		var row: String = LEVEL[y]
		for x in row.length():
			var ch := row[x]
			var pos := Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)
			match ch:
				"#":
					_add_wall(pos)
				"T":
					var t := Target.new()
					t.position = pos
					add_child(t)
				"P":
					spawn = pos

	player = Player.new()
	player.position = spawn
	add_child(player)
	add_child(fx)
	player.set_fx_layer(fx)

	var cam := Camera2D.new()
	player.add_child(cam)

	var layer := CanvasLayer.new()
	var hud := Label.new()
	hud.set_script(load("res://scripts/hud.gd"))
	hud.position = Vector2(8, 6)
	layer.add_child(hud)
	add_child(layer)
	hud.setup(player)


func _add_wall(pos: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE, TILE)
	shape.shape = rect
	body.add_child(shape)
	var vis := ColorRect.new()
	vis.size = Vector2(TILE, TILE)
	vis.position = -vis.size / 2.0
	vis.color = Color(0.22, 0.24, 0.27)
	body.add_child(vis)
	add_child(body)


func _draw() -> void:
	var w: int = LEVEL[0].length() * TILE
	var h: int = LEVEL.size() * TILE
	draw_rect(Rect2(0, 0, w, h), Color(0.12, 0.13, 0.12))
	for x in range(0, w, TILE):
		draw_line(Vector2(x, 0), Vector2(x, h), Color(1, 1, 1, 0.03))
	for y in range(0, h, TILE):
		draw_line(Vector2(0, y), Vector2(w, y), Color(1, 1, 1, 0.03))
