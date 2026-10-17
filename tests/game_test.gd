extends SceneTree
## Test meta-gry: śmierć (ciało, ubezpieczenie, poczta), odbiór ciała, zadania handlarzy, odblokowania, zapis.
## tools/gd.sh tests/game_test.gd 60

var _fails := 0


func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		print("FAIL ", msg)



func _initialize() -> void:
	seed(42)
	var game := root.get_node("Game")
	game.new_game()

	# --- śmierć: struktura
	game.equipment = Equipment.new()
	var rifle := Item.new("rifle_skm"); rifle.insured = true
	game.equipment.equip("primary", rifle)
	game.equipment.equip("armor", Item.new("armor_3"))
	var bp := Item.new("backpack_a"); bp.insured = true
	game.equipment.equip("backpack", bp)
	var sec := Item.new("secure_a")
	game.equipment.equip("secure", sec)
	sec.bag.add_auto(Item.new("watch"))
	bp.bag.add_auto(Item.new("ammo_556", 60))
	bp.bag.add_auto(Item.new("bandage", 2))
	game.equipment.pockets.add_auto(Item.new("tape"))
	game.raids_done = 5
	var d: Dictionary = game.process_death(game.equipment, "przedmiescia")
	_ok(game.equipment.get_slot("primary") == null and game.equipment.get_slot("armor") == null, "sprzęt zdjęty")
	_ok(game.equipment.get_slot("secure") == sec and sec.bag.count_of("watch") == 1, "bezpieczny kontener zostaje")
	_ok(not game.corpse.is_empty() and game.corpse["biome"] == "przedmiescia", "ciało zapisane")
	# w ciele: armor_3, ammo (z plecaka ubezp.), bandaże, tape; plecak i karabin ubezp. poza ciałem
	var ids := []
	for it in game.corpse["items"]:
		ids.append(it["id"])
	_ok("armor_3" in ids and "ammo_556" in ids and "bandage" in ids and "tape" in ids, "zawartość w ciele: %s" % [ids])
	_ok(not ("rifle_skm" in ids) and not ("backpack_a" in ids), "ubezpieczone nie leżą w ciele")
	_ok(d["insured_back"].size() + d["insured_lost"].size() == 2, "ubezpieczone rozliczone")
	for m in game.mail:
		if m["item"]["id"] == "backpack_a":
			_ok((m["item"].get("bag", []) as Array).is_empty(), "plecak z poczty pusty")
		_ok(int(m["ready"]) == 6, "poczta po kolejnym rajdzie")

	# --- statystyka zwrotów
	var back := 0
	for i in 400:
		game.mail = []
		game.equipment = Equipment.new()
		var r := Item.new("rifle_skm"); r.insured = true
		game.equipment.equip("primary", r)
		game.process_death(game.equipment, "przedmiescia")
		back += game.mail.size()
	var rate := back / 400.0
	print("zwrot ubezpieczenia ", rate)
	_ok(rate > 0.65 and rate < 0.85, "szansa zwrotu ~75%%: %f" % rate)

	# --- odbiór ciała
	game.mail = []
	game.corpse = {"biome": "kompleks", "items": [Item.new("watch").to_dict(), Item.new("tape").to_dict(),
		Item.new("lamp").to_dict(), Item.new("radio").to_dict(), Item.new("battery").to_dict()], "plundered": false}
	_ok(game.take_corpse_items("przedmiescia").is_empty(), "ciało tylko we właściwym biomie")
	var got: Array = game.take_corpse_items("kompleks")
	_ok(got.size() >= 2 and got.size() <= 5, "ciało po ogołoceniu: %d" % got.size())
	_ok(game.corpse["plundered"] == true, "flaga ogołocenia")
	_ok(game.take_corpse_items("kompleks").size() == 5, "drugi raz bez ogołacania")
	game.store_corpse_remaining("kompleks", [])
	_ok(game.corpse.is_empty(), "puste ciało znika")

	# --- poczta
	game.mail = [{"item": Item.new("rifle_skm").to_dict(), "ready": 9}]
	game.raids_done = 8
	_ok(game.collect_mail().is_empty() and game.mail.size() == 1, "poczta jeszcze nie dotarła")
	game.raids_done = 9
	var mailed: Array = game.collect_mail()
	_ok(mailed.size() == 1 and game.mail.is_empty() and game.stash.count_of("rifle_skm") >= 1, "poczta dotarła do skrytki")

	# --- odblokowanie i raport
	game.unlocked = ["przedmiescia"]
	var info: Dictionary = game.register_raid({"result": "extracted", "kills": {"Najemnicy": 2}, "start_value": 0, "end_value": 2000}, "przedmiescia")
	_ok(info["unlocked"] == "kompleks" and game.is_unlocked("kompleks"), "kompleks odblokowany")
	_ok(game.last_ctx == "profit", "kontekst profit: %s" % game.last_ctx)
	game.register_raid({"result": "dead", "kills": {}, "start_value": 0, "end_value": 0}, "przedmiescia")
	_ok(game.last_ctx == "after_death", "kontekst po śmierci")
	game.register_raid({"result": "dead", "kills": {}, "start_value": 0, "end_value": 0}, "przedmiescia")
	game.register_raid({"result": "dead", "kills": {}, "start_value": 0, "end_value": 0}, "przedmiescia")
	_ok(game.last_ctx == "many_deaths", "kontekst wiele śmierci")

	# --- zadania
	game.new_game()
	var m0: int = game.money
	game.accept_quest("kw1")
	_ok(not game.quest_ready("kw1"), "kw1 jeszcze niegotowe")
	game.stash.add_auto(Item.new("radio"))
	game.stash.add_auto(Item.new("radio"))
	_ok(game.quest_ready("kw1"), "kw1 gotowe po dostarczeniu")
	var res: String = game.complete_quest("kw1", 0)
	_ok(res == "900 bonów" and game.money == m0 + 900 and game.stash.count_of("radio") == 0, "kw1 nagroda pieniężna")
	_ok(game.current_quest("kw")["id"] == "kw2", "łańcuch zadań")
	game.accept_quest("kw2")
	game.register_raid({"result": "extracted", "kills": {"Najemnicy": 2}, "start_value": 0, "end_value": 0}, "przedmiescia")
	_ok(not game.quest_ready("kw2"), "kw2 2/3")
	game.register_raid({"result": "extracted", "kills": {"Najemnicy": 1}, "start_value": 0, "end_value": 0}, "przedmiescia")
	_ok(game.quest_ready("kw2"), "kw2 3/3")
	# brak miejsca
	var filler := Bag.grid(Game.STASH_COLS, Game.STASH_ROWS)
	game.stash = filler
	for i in 200:
		game.stash.add_auto(Item.new("backpack_a"))
	_ok(game.complete_quest("kw2", 1) == "NO_ROOM" and game.quest_state("kw2") == "active", "NO_ROOM nie zmienia stanu")
	game.stash = Bag.grid(Game.STASH_COLS, Game.STASH_ROWS)
	game.complete_quest("kw2", 1)
	_ok(game.stash.count_of("helmet_3") == 1 and game.stash.count_of("armor_3") == 1, "kw2 nagroda przedmiotowa")
	_ok(game.previous_choice("kw") == 1, "zapamiętany wybór")
	# zadanie extract
	game.accept_quest("pos1")
	game.stash.add_auto(Item.new("watch", 1))
	game.stash.add_auto(Item.new("watch", 1))
	game.stash.add_auto(Item.new("watch", 1))
	_ok(game.complete_quest("pos1", 0) == "700 bonów", "pos1")
	game.accept_quest("pos2")
	_ok(not game.quest_ready("pos2"), "pos2 wymaga ewakuacji z kompleksu")
	game.register_raid({"result": "extracted", "kills": {}, "start_value": 0, "end_value": 0}, "kompleks")
	_ok(game.quest_ready("pos2"), "pos2 po ewakuacji z kompleksu")

	# --- stawki skupu
	var tp = load("res://scripts/ui/trader_panel.gd").new()
	tp.trader = "kw"
	_ok(tp.sell_rate(Item.new("rifle_skm")) > 0.0 and tp.sell_rate(Item.new("watch")) == 0.0, "Wójt skupuje broń, nie zegarki")
	tp.trader = "med"
	_ok(tp.sell_rate(Item.new("bandage")) > 0.0 and tp.sell_rate(Item.new("sample")) > tp.sell_rate(Item.new("bandage")), "Ruda: leki i próbki")
	tp.trader = "pos"
	_ok(tp.sell_rate(Item.new("watch")) > 0.0 and tp.sell_rate(Item.new("rifle_skm")) == 0.0, "Sznurek bierze błyskotki")
	tp.free()

	# --- zapis i odczyt
	game.corpse = {"biome": "kompleks", "items": [Item.new("tape").to_dict()], "plundered": true}
	game.mail = [{"item": Item.new("armor_4").to_dict(), "ready": 3}]
	var ins := Item.new("pistol_p9"); ins.insured = true
	game.stash.add_auto(ins)
	game.selected_biome = "kompleks"
	game.save_game()
	var q_before: Dictionary = game.quests.duplicate(true)
	game.corpse = {}
	game.mail = []
	game.quests = {}
	game.unlocked = []
	game.selected_biome = "przedmiescia"
	_ok(game.load_game(), "load_game")
	_ok(game.corpse.get("biome", "") == "kompleks" and game.mail.size() == 1, "ciało i poczta po wczytaniu")
	_ok(game.selected_biome == "kompleks" and game.is_unlocked("kompleks"), "biom i odblokowania po wczytaniu")
	_ok(game.quest_state("kw2") == "done" and game.quest_state("pos2") == "active" and game.quests.size() == q_before.size(), "zadania po wczytaniu")
	var found_ins := false
	for it in game.stash.items:
		if it.id == "pistol_p9" and it.insured:
			found_ins = true
	_ok(found_ins, "flaga ubezpieczenia przetrwała zapis")

	print("GAME TEST ", "OK" if _fails == 0 else "FAIL")
	quit(0 if _fails == 0 else 1)
