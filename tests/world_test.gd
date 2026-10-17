extends SceneTree
## Test świata: rajd w kompleksie (elita, anomalia, ciało, mapa, wyjście) albo szkolenie krok po kroku.
## tools/gd.sh tests/world_test.gd 120 kompleks   |   tools/gd.sh tests/world_test.gd 120 tutorial

var _mode := "kompleks"
var _raid
var _frames := 0
var _fails := 0
var _anom_done := false
var _tut_state := 0
var _saved_eq


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_mode = args[0]
	seed(21)


func _ok(c: bool, m: String) -> void:
	if not c:
		_fails += 1
		print("FAIL ", m)


func _setup() -> void:
	var game := root.get_node("Game")
	game.new_game()
	game.equipment.equip("primary", _loaded("rifle_skm"))
	game.equipment.equip("armor", Item.new("armor_3"))
	game.equipment.equip("backpack", Item.new("backpack_a"))
	game.equipment.equip("rig", Item.new("rig_a"))
	game.equipment.add_auto(Item.new("ammo_556", 90), true)
	_saved_eq = game.equipment
	if _mode == "kompleks":
		game.corpse = {"biome": "kompleks", "items": [Item.new("watch").to_dict(), Item.new("tape").to_dict(),
			Item.new("armor_4").to_dict(), Item.new("lamp").to_dict()], "plundered": true}
		game.unlocked = ["przedmiescia", "kompleks"]
		game.next_raid = {"biome": "kompleks", "tutorial": false}
	else:
		game.next_raid = {"tutorial": true, "biome": "szkolenie"}
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
	if _mode == "kompleks":
		_kompleks()
	else:
		_tutorial()
	if _frames > 60 * 60:
		print("FAIL timeout")
		quit(1)
	return false


func _kompleks() -> void:
	var game := root.get_node("Game")
	var player = _raid.player
	if _frames == 10:
		_ok(_raid.biome == "kompleks", "biom kompleks")
		_ok(_raid.level["size"].x == 80, "poziom 5 pokoi szerokości")
		var elites := 0
		for e in _raid.enemies:
			if e.elite:
				elites += 1
		_ok(elites == 1, "dokładnie jedna elita: %d" % elites)
		_ok(_raid.corpse_box != null and _raid.corpse_box in _raid.boxes, "własne ciało w terenie")
		_ok(_raid.corpse_box.bag.items.size() == 4, "ciało z 4 przedmiotami: %d" % _raid.corpse_box.bag.items.size())
		_ok(_raid.anomaly_rect.position.x >= 0, "pokój anomalii")
		var ad := 0
		for b in _raid.boxes:
			if b.kind == "anomalia":
				ad += 1
		_ok(ad >= 1, "skrzynie anomalii: %d" % ad)
		var seen := 0
		for v in _raid.explored:
			seen += v
		_ok(seen > 20, "mgła wojny odsłania pole: %d" % seen)
		for e in _raid.enemies:
			e.global_position = Vector2(-5000, -5000)
	if _frames == 20:
		# wejście do pokoju anomalii
		var r: Rect2i = _raid.anomaly_rect
		var c := Vector2(r.position.x + 3, r.position.y + 3) * 32.0 + Vector2(16, 16)
		player.global_position = c
	if _frames == 30:
		_ok(_raid.in_anomaly and _raid.stats["anomaly"], "anomalia wykryta")
		_ok(_raid.banner.text != "", "komunikat o anomalii")
		var t0: float = _raid.threat
		_raid._process(1.0)
		_ok(_raid.threat > t0 + 1.0, "zagrożenie rośnie w anomalii")
		# otwórz mapę
		_raid.map_view.toggle()
	if _frames == 40:
		# zabierz jedną rzecz z ciała i wyjdź
		var cb = _raid.corpse_box
		var it = cb.bag.items[0]
		cb.bag.remove(it)
		_raid.player.equipment.add_auto(it)
		_raid.player.global_position = _raid.exits[0]["pos"]
		_raid.map_view.toggle()
		for e in _raid.enemies:
			e.global_position = Vector2(-5000, -5000)
	if _frames > 40 and _raid.finished:
		_ok(game.extractions == 1, "ewakuacja policzona")
		_ok(game.corpse.get("items", []).size() == 3, "ciało zachowało resztę: %d" % game.corpse.get("items", []).size())
		_ok(game.last_report.get("corpse_taken", -1) == 1, "raport: odzyskano 1")
		print("WORLD(kompleks) ", "OK" if _fails == 0 else "FAIL")
		quit(0 if _fails == 0 else 1)


func _tutorial() -> void:
	var game := root.get_node("Game")
	var player = _raid.player
	var tut = _raid.tutorial
	if _frames == 10:
		_ok(_raid.tutorial_mode and tut != null, "tryb szkolenia")
		_ok(_raid.enemies.size() == 1 and _raid.level["spawns"].is_empty(), "jeden wróg szkoleniowy")
		_ok(game.equipment != _saved_eq, "zestaw szkoleniowy zamiast prawdziwego")
		_ok(_raid.hint_label.text.begins_with("[1/7]"), "podpowiedź 1")
		# wróg szkoleniowy nie przeszkadza w krokach 0-4
		_raid.enemies[0].global_position = _raid.enemies[0].global_position
	if _frames == 12:
		player.global_position += Vector2(200, 0)
	if _frames == 20:
		_ok(tut.step == 1, "krok 1 po ruchu: %d" % tut.step)
		for t in _raid._tutorial_targets:
			for i in 6:
				t.take_hit(40.0, Vector2.RIGHT)
	if _frames == 30:
		_ok(tut.step == 2, "krok 2 po manekinach: %d" % tut.step)
		player.weapon_item.loaded = 5
		player._start_reload()
	if _frames == 30 + 60 * 5:
		_ok(tut.step == 3, "krok 3 po przeładowaniu: %d" % tut.step)
		var box = _raid.boxes[0]
		player.global_position = box.global_position + Vector2(0, 20)
		_raid.inv_ui.open_box(box)
		_raid.stats["boxes_opened"] += 1
		player.input_locked = true
	if _frames == 30 + 60 * 5 + 5:
		_ok(tut.step == 4, "krok 4 po otwarciu: %d" % tut.step)
		_raid.inv_ui.close()
	if _frames == 30 + 60 * 5 + 10:
		_ok(tut.step == 5, "krok 5 po zamknięciu ekwipunku: %d" % tut.step)
		for e in _raid.enemies.duplicate():
			for i in 40:
				if is_instance_valid(e) and e.body.alive:
					e.take_hit(60.0, Vector2.RIGHT, 6)
	if _frames == 30 + 60 * 5 + 20:
		_ok(tut.step == 6, "krok 6 po wrogu: %d" % tut.step)
		player.body.blood = 100.0
		player.global_position = _raid.exits[0]["pos"]
	if _frames > 30 + 60 * 5 + 20 and _raid.finished:
		_ok(game.tutorial_done, "szkolenie zaliczone")
		_ok(game.equipment == _saved_eq, "prawdziwy sprzęt przywrócony")
		_ok(game.raids_done == 0 and game.extractions == 0, "szkolenie nie liczy się do statystyk")
		_ok(game.last_report.get("result", "") == "tutorial_ok", "raport szkolenia")
		print("WORLD(tutorial) ", "OK" if _fails == 0 else "FAIL")
		quit(0 if _fails == 0 else 1)
