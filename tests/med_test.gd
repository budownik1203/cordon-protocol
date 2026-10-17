extends SceneTree
## Test leczenia per część: bandaż, szyna, apteczka, operacja, hotbar, tabletki.

var _frames := 0
var _main: Node
var _p
var _fail := 0
var _bandages := 0


func _ok(c: bool, m: String) -> void:
	if not c:
		_fail += 1
		print("FAIL ", m)


func _initialize() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 3:
		_p = _main.player
		var eq = _p.equipment
		eq.equip("backpack", Item.new("backpack_a"))
		_bandages = eq.count_of("bandage")
		for id in ["bandage", "hemostatic", "splint", "medkit", "surgery", "painkiller"]:
			_ok(eq.add_auto(Item.new(id), true), "dodano " + id)
		_bandages = eq.count_of("bandage")
		var b = _p.body
		b.bleed[Body.Part.L_ARM] = 1
		b.fracture[Body.Part.R_LEG] = true
		b.hp[Body.Part.STOMACH] = 30.0
		_ok(_p.start_use("bandage", Body.Part.R_LEG) != "", "bandaż na nogę bez krwawienia odrzucony")
		_ok(_p.start_use("bandage", Body.Part.L_ARM) == "" and _p.using_item == "bandage", "bandaż startuje na lewej ręce")
	if _frames == 3 + 60 * 5:
		var b2 = _p.body
		_ok(b2.bleed[Body.Part.L_ARM] == 0, "lewa ręka przestała krwawić")
		_ok(_p.equipment.count_of("bandage") == _bandages - 1, "bandaż zużyty")
		_ok(_p.start_use("splint") == "" and _p.using_part == Body.Part.R_LEG, "szyna auto na prawą nogę")
	if _frames == 3 + 60 * 5 + 60 * 9:
		var b3 = _p.body
		_ok(not b3.fracture[Body.Part.R_LEG], "złamanie naprawione")
		_ok(_p.start_use("medkit", Body.Part.STOMACH) == "", "apteczka na brzuch")
	if _frames == 3 + 60 * 5 + 60 * 9 + 60 * 8:
		var b4 = _p.body
		_ok(b4.hp[Body.Part.STOMACH] > 69.0, "brzuch wyleczony: %f" % b4.hp[Body.Part.STOMACH])
		var found = _p.equipment.find_item("medkit")
		_ok(not found.is_empty() and found["item"].durability < 150.0, "zasób apteczki zmalał")
		b4.apply_hit(Body.Part.R_ARM, 75.0, 6)
		_ok(b4.blacked(Body.Part.R_ARM), "ręka zniszczona")
		_ok(_p.start_use("splint", Body.Part.R_ARM) != "", "szyna nie działa na zniszczoną")
		_ok(_p.start_use("surgery", Body.Part.R_ARM) == "", "operacja startuje")
	if _frames == 3 + 60 * 5 + 60 * 9 + 60 * 8 + 60 * 40:
		var b5 = _p.body
		_ok(not b5.blacked(Body.Part.R_ARM), "ręka przywrócona")
		_ok(b5.max_hp[Body.Part.R_ARM] < 60.0, "kara do maks. HP po operacji")
		# hotbar: domyślnie 1 = bandaż, 4 = tabletki
		var Game = root.get_node("Game")
		_ok(Game.hotbar[0] == "bandage" and Game.hotbar[3] == "painkiller", "domyślny hotbar")
		_p.start_use("painkiller")
	if _frames == 3 + 60 * 5 + 60 * 9 + 60 * 8 + 60 * 40 + 60 * 4:
		_ok(_p.body.painkilled(), "tabletki działają")
		print("MED TEST ", "OK" if _fail == 0 else "FAIL(%d)" % _fail)
		quit(0 if _fail == 0 else 1)
	return false
