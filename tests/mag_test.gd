extends SceneTree
## Test magazynków: wymiana, ręczne dobijanie, pakowanie (C), ładowanie w ekwipunku, sortowanie.
## godot --headless --path . --script res://tests/mag_test.gd

var _frames := 0
var _main: Node
var _p
var _ui
var _fail := 0


func _ok(c: bool, msg: String) -> void:
	if not c:
		_fail += 1
		print("FAIL: ", msg)


func _initialize() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _spares() -> Array:
	return _p.spare_mags()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 3:
		_p = _main.player
		_ok(_p.ammo == 30, "start 30 w magazynku: %d" % _p.ammo)
		_ok(_spares().size() == 3, "3 zapasowe magazynki: %d" % _spares().size())
		_ok(_p.loose_ammo() == 60, "60 luzem: %d" % _p.loose_ammo())
		_p.weapon_item.mag.loaded = 5
		_p._start_reload()
		_ok(_p.reloading and _p.reload_kind == "swap", "wymiana magazynka")
	if _frames == 3 + 60 * 2:
		_ok(not _p.reloading, "wymiana skończona")
		_ok(_p.ammo == 30, "po wymianie 30: %d" % _p.ammo)
		_ok(_p.spare_rounds() == 30 + 30 + 5, "zapas 65: %d" % _p.spare_rounds())
		# drugi test: brak zapasów -> ręczne dobijanie
		for m in _spares():
			m["item"].loaded = 0
		_p.weapon_item.mag.loaded = 25
		_ok(_p.best_spare().is_empty(), "brak naładowanych zapasów")
		_ok(_p.can_reload(), "można dobijać luzem")
		_p._start_reload()
		_ok(_p.reload_kind == "feed", "tryb feed")
	if _frames == 3 + 60 * 2 + 60 * 4:
		_ok(_p.ammo == 30, "dobito do 30: %d" % _p.ammo)
		_ok(_p.loose_ammo() == 55, "luzem 55: %d" % _p.loose_ammo())
		# pakowanie C
		_p.start_combine()
		_ok(_p.loading_mags, "pakowanie startuje")
	if _frames == 3 + 60 * 2 + 60 * 4 + 60 * 8:
		_ok(not _p.loading_mags, "pakowanie skończone")
		var total := 0
		for m in _spares():
			total += m["item"].loaded
		_ok(total == 55, "55 naboi w zapasach: %d" % total)
		_ok(_p.loose_ammo() == 0, "luzem 0: %d" % _p.loose_ammo())
		# ekwipunek UI
		_ui = load("res://scripts/ui/inventory_ui.gd").new()
		root.add_child(_ui)
		_ui.setup(_p.equipment, _p, true)
		_ui.open_player()
		var eq = _p.equipment
		eq.add_auto(Item.new("ammo_556", 40), true)
		var empty_mag
		for m in eq.find_mags("mag_556_30"):
			m["item"].loaded = 0
			empty_mag = m["item"]
		_ui.refresh()
		_ui.held = eq.pockets.items[0] if false else null
		# trzymana amunicja -> ładowanie do magazynku
		var stack: Item = null
		for e in eq.bags():
			for it in e["bag"].items:
				if it.id == "ammo_556":
					stack = it
					e["bag"].remove(it)
					break
			if stack:
				break
		_ok(stack != null, "znaleziono stos amunicji")
		_ui.held = stack
		_ui._start_load_held(empty_mag)
	if _frames == 3 + 60 * 2 + 60 * 4 + 60 * 8 + 60 * 3:
		var any_full := false
		for m in _spares():
			if m["item"].loaded == 30:
				any_full = true
		_ok(any_full, "magazynek załadowany z ręki")
		_ok(_ui.held == null or _ui.held.count < 40, "stos z ręki się zużył: %s" % [_ui.held.count if _ui.held else 0])
		_ui._sort_all()
		_ok(_ui._ghosts is Array, "sortowanie bez błędu")
	if _frames == 3 + 60 * 2 + 60 * 4 + 60 * 8 + 60 * 3 + 30:
		# strzał z pustym magazynkiem uruchamia automatyczną wymianę
		_p.reloading = false
		_p.weapon_item.mag.loaded = 1
		_p._cooldown = 0.0
		_p._fire()
		_ok(_p.ammo == 0, "ostatni nabój wystrzelony: %d" % _p.ammo)
		_p._cooldown = 0.0
		_p._fire()
		_ok(_p.reloading and _p.reload_kind == "swap", "pusty magazynek: auto-wymiana")
		print("MAG TEST ", "OK" if _fail == 0 else "FAIL(%d)" % _fail)
		quit(0 if _fail == 0 else 1)
	return false
