extends SceneTree
## Test obciążeniowy: bot gra rajd kilka minut (chodzi losowo, strzela do wrogów). Szuka błędów skryptów.
## godot --headless --fixed-fps 60 --path . --script res://tests/bot_test.gd

var _raid: Node2D
var _frames := 0
var _dir_t := 0
var _dirs := ["move_left", "move_right", "move_up", "move_down"]
var _held := []
var _shots := 0
var _seed := 3


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_seed = int(args[0])
	seed(_seed)


func _setup() -> void:
	var game := root.get_node("Game")
	game.new_game()
	var rifle := Item.new("rifle_skm")
	game.equipment.equip("primary", rifle)
	game.equipment.equip("armor", Item.new("armor_3"))
	game.equipment.equip("head", Item.new("helmet_2"))
	game.equipment.equip("rig", Item.new("rig_a"))
	game.equipment.equip("backpack", Item.new("backpack_a"))
	game.equipment.add_auto(Item.new("ammo_556", 300), true)
	game.equipment.add_auto(Item.new("bandage", 4), true)
	game.equipment.add_auto(Item.new("hemostatic", 2), true)
	_raid = load("res://scenes/raid.tscn").instantiate()
	root.add_child(_raid)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		_setup()
		return false
	if _raid == null:
		return false
	if _raid.finished:
		var g := root.get_node("Game")
		print("BOT finished after ", _frames, " frames; shots=", _shots, " deaths=", g.deaths, " extractions=", g.extractions)
		print("BOT TEST OK")
		quit(0)
		return true
	var p: Player = _raid.player
	if p == null or not p.is_alive():
		return false
	_dir_t -= 1
	if _dir_t <= 0:
		_dir_t = randi_range(30, 120)
		for a in _held:
			Input.action_release(a)
		_held = []
		for i in randi_range(1, 2):
			var a: String = _dirs[randi() % 4]
			Input.action_press(a)
			_held.append(a)
	# strzelaj do najbliższego widocznego celu
	var best: Node2D = null
	var bd := 260.0
	for e in _raid.enemies:
		if is_instance_valid(e) and e.visible:
			var d: float = e.global_position.distance_to(p.global_position)
			if d < bd:
				bd = d
				best = e
	for f in _raid.faunas:
		if is_instance_valid(f) and f.visible and f.alive:
			var d2: float = f.global_position.distance_to(p.global_position)
			if d2 < bd:
				bd = d2
				best = f
	if best:
		p._aim_dir = (best.global_position - p.global_position).normalized()
		if p._cooldown <= 0.0 and not p.reloading and p.weapon:
			p._fire()
			_shots += 1
	if p.body.blood < 60.0 and p.using_item == "":
		Input.action_press("use_hemostatic")
	else:
		Input.action_release("use_hemostatic")
	if p.ammo <= 0 and not p.reloading and p.reserve_ammo() > 0:
		Input.action_press("reload")
	else:
		Input.action_release("reload")
	if _frames > 60 * 240:
		print("BOT survived 4 minutes; shots=", _shots, " enemies=", _raid.enemies.size(), " fauna=", _raid.faunas.size(), " threat=", int(_raid.threat))
		print("BOT TEST OK")
		quit(0)
	return false
