extends Node2D
## Prototyp 2: pokój z osłonami, rany i dwóch wrogów z AI (osłona, flankowanie, radio).
## Legenda: # ściana, c osłona, P gracz, E wróg, T manekin.

const TILE := 32

const LEVEL := [
	"##############################",
	"#............#...............#",
	"#............#...............#",
	"#..P.........................#",
	"#............#.......c.......#",
	"#..........c.#...............#",
	"#............#.....E.........#",
	"#............#...............#",
	"#.....T......###.....c.......#",
	"#............................#",
	"#..........c.....E...........#",
	"#............#...............#",
	"##############################",
]

var player: Player
var nav: GridNav
var group: GroupManager


func _ready() -> void:
	var fx := Node2D.new()
	fx.set_script(load("res://scripts/fx_layer.gd"))
	fx.z_index = 10

	nav = GridNav.new(LEVEL, TILE)
	group = GroupManager.new()
	group.nav = nav
	add_child(group)

	var spawn := Vector2(64, 64)
	var enemy_spots: Array = []
	for y in LEVEL.size():
		var row: String = LEVEL[y]
		for x in row.length():
			var ch := row[x]
			var pos := Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)
			match ch:
				"#":
					_add_block(pos, Color(0.22, 0.24, 0.27), 1.0)
				"c":
					_add_block(pos, Color(0.42, 0.36, 0.26), 0.6)
				"T":
					var t := Target.new()
					t.position = pos
					add_child(t)
				"P":
					spawn = pos
				"E":
					enemy_spots.append(pos)

	player = Player.new()
	player.position = spawn
	add_child(player)
	player.setup(_arena_kit())
	add_child(fx)
	player.set_fx_layer(fx)

	for pos in enemy_spots:
		var e := Enemy.new()
		e.position = pos
		add_child(e)
		e.setup(nav, player, fx)
		group.add_member(e)

	var cam := Camera2D.new()
	player.add_child(cam)

	var layer := CanvasLayer.new()
	var hud := Label.new()
	hud.set_script(load("res://scripts/hud.gd"))
	hud.position = Vector2(8, 6)
	hud.add_theme_font_size_override("font_size", 10)
	layer.add_child(hud)
	add_child(layer)
	hud.setup(player)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
	if player:
		player.queue_redraw()


## Zestaw do areny testowej (niezależny od zapisu gry).
func _arena_kit() -> Equipment:
	var eq := Equipment.new()
	eq.equip("primary", Item.make_weapon("rifle_skm"))
	eq.equip("armor", Item.new("armor_3"))
	eq.equip("head", Item.new("helmet_2"))
	eq.equip("rig", Item.new("rig_a"))
	for i in 3:
		var m := Item.new("mag_556_30")
		m.loaded = 30
		eq.add_auto(m, true)
	eq.add_auto(Item.new("ammo_556", 60), true)
	eq.add_auto(Item.new("bandage", 3), true)
	eq.add_auto(Item.new("hemostatic", 1), true)
	eq.add_auto(Item.new("splint", 1), true)
	eq.add_auto(Item.new("painkiller", 2), true)
	return eq


func _add_block(pos: Vector2, color: Color, scale_: float) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE, TILE)
	shape.shape = rect
	body.add_child(shape)
	var vis := ColorRect.new()
	vis.size = Vector2(TILE, TILE) * scale_
	vis.position = -vis.size / 2.0
	vis.color = color
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
