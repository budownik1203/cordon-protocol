extends SceneTree
## Test rajdu: generuje poziom, przeszukuje kontener, wychodzi wyjściem otwartym.
## godot --headless --fixed-fps 60 --path . --script res://tests/raid_test.gd

var _raid: Node2D
var _frames := 0
var _fails := 0


func _initialize() -> void:
	seed(11)


func _setup() -> void:
	var game := root.get_node("Game")
	game.new_game()
	game.equipment.equip("primary", _loaded("rifle_skm"))
	game.equipment.equip("armor", Item.new("armor_3"))
	game.equipment.equip("backpack", Item.new("backpack_a"))
	game.equipment.equip("rig", Item.new("rig_a"))
	game.equipment.add_auto(Item.new("ammo_556", 90), true)
	game.equipment.add_auto(Item.new("bandage", 3), true)
	_raid = load("res://scenes/raid.tscn").instantiate()
	root.add_child(_raid)


func _loaded(id: String) -> Item:
	var it := Item.new(id)
	it.loaded = 30
	return it


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		_setup()
		return false
	if _raid == null:
		return false
	var player: Player = _raid.player
	if _frames == 6:
		print("enemies=", _raid.enemies.size(), " boxes=", _raid.boxes.size(), " exits=", _raid.exits.size())
		if _raid.boxes.is_empty() or _raid.exits.size() < 2:
			_fails += 1; print("FAIL world")
	if _frames == 32:
		# poczekaj na wygenerowane światło i sprawdź, że widoczność działa
		print("sees own pos: ", player.can_see_point(player.global_position + Vector2(20, 0)))
	if _frames == 202:
		var box: LootBox = _raid.boxes[0]
		player.global_position = box.global_position + Vector2(0, 20)
		player.body.blood = 100.0
		_raid.inv_ui.open_box(box)
		print("opened box ", box.display_name(), " items=", box.bag.items.size())
	if _frames == 202 + 60 * 5:
		var box2: LootBox = _raid.boxes[0]
		var hidden := 0
		for it in box2.bag.items:
			if not it.revealed:
				hidden += 1
		print("hidden after 5s=", hidden)
		if hidden != 0:
			_fails += 1; print("FAIL reveal")
		_raid.inv_ui.close()
	if _frames == 702:
		# strzał do wroga wyżej niż ściany nic nie psuje; przeskocz do wyjścia
		var ex: Dictionary = _raid.exits[0]
		player.global_position = ex["pos"]
		# wyłącz wrogów dla czystości testu
		for e in _raid.enemies:
			e.global_position = Vector2(-5000, -5000)
	if _frames > 702 and _raid.finished:
		var g := root.get_node("Game")
		print("extractions=", g.extractions, " raids=", g.raids_done)
		if g.extractions != 1:
			_fails += 1; print("FAIL not extracted")
		print("RAID TEST ", "OK" if _fails == 0 else "FAIL")
		quit(0 if _fails == 0 else 1)
	if _frames > 60 * 40:
		print("FAIL timeout")
		quit(1)
	return false
