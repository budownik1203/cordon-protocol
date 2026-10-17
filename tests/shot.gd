extends SceneTree
## Zrzuty ekranu do podglądu (wymaga okna/Xvfb): godot --path . --script res://tests/shot.gd -- <scena> <plik.png> [klatki]

var _frames := 0
var _out := ""
var _wait := 40
var _scene := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_scene = args[0]
	_out = args[1]
	if args.size() > 2:
		_wait = int(args[2])
	seed(5)


func _setup() -> void:
	var game := root.get_node("Game")
	game.new_game()
	game.tutorial_done = true
	game.contract_seen = true
	game.unlocked = ["przedmiescia", "kompleks"]
	game.next_raid = {"biome": "przedmiescia", "tutorial": false}
	if _scene == "kompleks":
		game.next_raid = {"biome": "kompleks", "tutorial": false}
		game.corpse = {"biome": "kompleks", "items": [Item.new("armor_4").to_dict(), Item.new("watch").to_dict()], "plundered": true}
		game.equipment.equip("primary", _l("rifle_skm"))
		game.equipment.equip("armor", Item.new("armor_3"))
		game.equipment.equip("head", Item.new("helmet_2"))
		game.equipment.equip("backpack", Item.new("backpack_a"))
		game.equipment.add_auto(Item.new("ammo_556", 90), true)
		root.add_child(load("res://scenes/raid.tscn").instantiate())
	elif _scene == "tut":
		game.tutorial_done = false
		game.next_raid = {"tutorial": true, "biome": "szkolenie"}
		root.add_child(load("res://scenes/raid.tscn").instantiate())
	elif _scene == "contract":
		game.tutorial_done = false
		game.contract_seen = false
		root.add_child(load("res://scenes/base.tscn").instantiate())
	elif _scene == "report":
		game.pending_report = {"result": "dead", "time": 412.0, "kills": {"Najemnicy": 2, "Elita": 1, "Fauna": 1}, "biome": "kompleks",
			"cause": "Wykrwawienie", "last_source": "", "start_value": 4200, "end_value": 300, "arms_hurt": true, "boxes": 6, "threat": 120,
			"anomaly": true, "corpse_items": 9, "had_old_corpse": true, "insured_back": ["Karabin SKM-74"], "insured_lost": ["Plecak Szturmowy"],
			"unlocked": ""}
		root.add_child(load("res://scenes/base.tscn").instantiate())
	elif _scene == "raid":
		game.equipment.equip("primary", _l("rifle_skm"))
		game.equipment.equip("armor", Item.new("armor_3"))
		game.equipment.equip("head", Item.new("helmet_2"))
		game.equipment.equip("backpack", Item.new("backpack_a"))
		game.equipment.equip("rig", Item.new("rig_a"))
		game.equipment.add_auto(Item.new("ammo_556", 90), true)
		root.add_child(load("res://scenes/raid.tscn").instantiate())
	elif _scene == "base":
		game.equipment.equip("primary", _l("rifle_skm"))
		game.equipment.equip("backpack", Item.new("backpack_b"))
		game.equipment.equip("rig", Item.new("rig_a"))
		game.equipment.add_auto(Item.new("ammo_556", 60), true)
		root.add_child(load("res://scenes/base.tscn").instantiate())
	elif _scene == "mapui":
		game.next_raid = {"biome": "kompleks", "tutorial": false}
		game.corpse = {"biome": "kompleks", "items": [Item.new("watch").to_dict()], "plundered": true}
		game.equipment.equip("primary", _l("rifle_skm"))
		root.add_child(load("res://scenes/raid.tscn").instantiate())
		_wait = 440
	elif _scene == "map":
		game.equipment.equip("primary", _l("rifle_skm"))
		root.add_child(load("res://scenes/raid.tscn").instantiate())
	elif _scene == "inv" or _scene == "invload" or _scene == "invfly":
		game.equipment.equip("primary", _l("rifle_skm"))
		for k in 3:
			var mg := Item.new("mag_556_30")
			mg.loaded = [30, 0, 11][k]
			game.equipment.add_auto(mg, true)
		game.equipment.equip("backpack", Item.new("backpack_a"))
		game.equipment.equip("rig", Item.new("rig_a"))
		game.equipment.equip("belt", Item.new("belt_a"))
		game.equipment.add_auto(Item.new("ammo_556", 90), true)
		game.equipment.add_auto(Item.new("bandage", 3), true)
		var r: Node = load("res://scenes/raid.tscn").instantiate()
		root.add_child(r)
		_wait = maxi(_wait, 30)


func _l(id: String) -> Item:
	return Item.make_weapon(id)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		_setup()
		return false
	if _scene == "mapui" and _frames == 5:
		pass
	if _scene == "mapui" and _frames > 5 and _frames < 400 and _frames % 6 == 0:
		var rd: Node = root.get_child(root.get_child_count() - 1)
		var i := _frames / 6
		var rooms: Array = rd.level["grid_rooms"]
		var rp: Vector2i = rooms[i % rooms.size()]
		rd.player.global_position = Vector2(rp.x * 16 + 7, rp.y * 12 + 5) * 32.0 + Vector2(16, 16)
		rd._mark_explored()
		for e in rd.enemies:
			e.global_position = Vector2(-5000, -5000)
	if _scene == "mapui" and _frames == 420:
		var rd2: Node = root.get_child(root.get_child_count() - 1)
		rd2.map_view.toggle()
		rd2.player.global_position = rd2.level["start"]
	if _scene == "map" and _frames == 22:
		var raid: Node = root.get_child(root.get_child_count() - 1)
		raid.cam.zoom = Vector2(0.3, 0.3)
		raid.player.global_position = Vector2(1024, 576)
		for c in raid.get_children():
			if c is CanvasModulate:
				c.color = Color(1, 1, 1)
		for e in raid.enemies:
			e.visible = true
	if _scene == "invload" and _frames == 22:
		var raid3: Node = root.get_child(root.get_child_count() - 1)
		raid3.inv_ui.open_player()
		var eq = root.get_node("Game").equipment
		var empty = null
		var k2 := 0
		for m in eq.find_mags("mag_556_30"):
			m["item"].loaded = [0, 11, 30][k2 % 3]
			k2 += 1
			if m["item"].loaded == 0:
				empty = m["item"]
		eq.add_auto(Item.new("ammo_556", 40), true)
		var stack = null
		for e in eq.bags():
			for it in e["bag"].items:
				if it.id == "ammo_556" and stack == null:
					stack = it
					e["bag"].remove(it)
		raid3.inv_ui.held = stack
		raid3.inv_ui._held_pos = Vector2(60, 150)
		raid3.inv_ui.refresh()
		raid3.inv_ui._start_load_held(empty)
	if _scene == "invfly" and _frames == 22:
		var raid4: Node = root.get_child(root.get_child_count() - 1)
		var box4 = raid4.boxes[0]
		raid4.player.global_position = box4.global_position + Vector2(0, 20)
		raid4.inv_ui.open_box(box4)
		for it in box4.bag.items:
			it.revealed = true
		raid4.inv_ui.refresh()
		raid4.inv_ui._take_all()
	if _scene == "inv" and _frames == 22:
		var raid: Node = root.get_child(root.get_child_count() - 1)
		var box = raid.boxes[0]
		raid.player.global_position = box.global_position + Vector2(0, 20)
		raid.inv_ui.open_box(box)
		for it in box.bag.items:
			it.revealed = true
		raid.inv_ui.refresh()
	if _frames == _wait:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(_out)
		print("saved ", _out, " ", img.get_size())
		quit(0)
	return false
