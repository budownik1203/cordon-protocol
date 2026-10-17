class_name InventoryUI
extends CanvasLayer
## Ekran ekwipunku: sloty, pojemniki gracza, drugi pojemnik (łup lub skrytka), handlarz w bazie.
## LPM: weź/połóż, PPM: szybka akcja (załóż / przenieś), R: obróć trzymany przedmiot.

signal closed
signal money_changed

const CELL := GridView.CELL

var equipment: Equipment
var player: Player
var raid_mode: bool = true
var current_box: LootBox = null
var other_bag: Bag = null
var other_title: String = ""
var held: Item = null
var held_src: Bag = null

var _root: Control
var _slot_views: Dictionary = {}
var _dyn: Control  # dynamiczne siatki
var _info: Label
var _weight: Label
var _msg: Label
var _held_draw: Control
var trader_panel: TraderPanel
var _msg_t: float = 0.0
var _grids: Array = []
var _hidden: Dictionary = {}  # Item -> true: ukryte w siatce, bo leci do nich duch
var _ghosts: Array = []  # animowane "loty" przedmiotów i nabojów
var _held_pos := Vector2(320, 180)  # wygładzona pozycja trzymanego przedmiotu (środek)
var _held_lift: float = 0.0
var _job: Dictionary = {}  # aktywne ładowanie magazynków
var _btn_all: Button
var _btn_sort: Button
var _btn_load: Button
var _body_view: BodyView
var _hb: Control  # edytor paska szybkiego dostępu
var _hb_hover: int = -1
var _hover_item: Item = null

const LOAD_TICK := 0.06
const FLY_TIME := 0.16


func setup(eq: Equipment, plr: Player, p_raid: bool) -> void:
	equipment = eq
	player = plr
	raid_mode = p_raid
	_root = Control.new()
	_root.size = Vector2(640, 360)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var bg := ColorRect.new()
	bg.size = Vector2(640, 360)
	bg.color = Color(0.05, 0.06, 0.07, 1.0)
	_root.add_child(bg)

	var t := Label.new()
	t.text = "OPERATOR"
	t.position = Vector2(6, 4)
	t.add_theme_font_size_override("font_size", 8)
	_root.add_child(t)

	var order := ["head", "armor", "rig", "backpack", "belt", "secure", "primary", "pistol"]
	for i in order.size():
		var sv := SlotView.new()
		sv.slot = order[i]
		sv.equipment = equipment
		sv.position = Vector2(6 + (i % 2) * 58, 16 + (i / 2) * 36)
		sv.slot_input.connect(_on_slot_input)
		sv.hovered.connect(func(_v, it): _show_info(it))
		_root.add_child(sv)
		_slot_views[order[i]] = sv

	_weight = Label.new()
	_weight.position = Vector2(6, 164)
	_weight.add_theme_font_size_override("font_size", 8)
	_root.add_child(_weight)

	_info = Label.new()
	_info.position = Vector2(6, 196) if not raid_mode else Vector2(124, 214)
	_info.size = Vector2(112, 150) if not raid_mode else Vector2(116, 64)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_font_size_override("font_size", 8)
	_info.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	_root.add_child(_info)

	_dyn = Control.new()
	_root.add_child(_dyn)

	_msg = Label.new()
	_msg.position = Vector2(124, 284)
	_msg.add_theme_font_size_override("font_size", 8)
	_msg.add_theme_color_override("font_color", Color(1, 0.7, 0.4))
	_root.add_child(_msg)

	if raid_mode and player != null:
		var bt := Label.new()
		bt.text = "STAN CIAŁA"
		bt.position = Vector2(6, 187)
		bt.add_theme_font_size_override("font_size", 7)
		bt.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75))
		_root.add_child(bt)
		_body_view = BodyView.new()
		_body_view.setup(player.body, 1.3, true, true, player)
		_body_view.position = Vector2(4, 196)
		_body_view.part_input.connect(_on_body_input)
		_body_view.part_hovered.connect(_on_body_hover)
		_root.add_child(_body_view)
	var hl := Label.new()
	hl.text = "PASEK SZYBKIEGO DOSTĘPU (trzymaj środek i kliknij slot, albo najedź na środek i wciśnij 1-9; PPM czyści)"
	hl.position = Vector2(244, 248)
	hl.add_theme_font_size_override("font_size", 6)
	hl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	_root.add_child(hl)
	_hb = Control.new()
	_hb.position = Vector2(244, 258)
	_hb.size = Vector2(Game.HOTBAR_SIZE * 24.0, 22.0)
	_hb.draw.connect(_draw_hotbar)
	_hb.gui_input.connect(_on_hotbar_input)
	_hb.mouse_exited.connect(func(): _hb_hover = -1)
	_root.add_child(_hb)
	_btn_load = _small_button("Załaduj mag. [V]", Vector2(124, 298), Vector2(96, 16), _start_load_all)
	_btn_load.tooltip_text = "Pakuje luźną amunicję do magazynków (animowane, klik przerywa)."
	_btn_sort = _small_button("Sortuj", Vector2(224, 298), Vector2(40, 16), _sort_all)
	_btn_all = _small_button("Weź wszystko", Vector2(268, 298), Vector2(70, 16), _take_all)
	_btn_all.visible = false

	_held_draw = Control.new()
	_held_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held_draw.size = Vector2(640, 360)
	_held_draw.z_index = 50
	_held_draw.draw.connect(_draw_held)
	_root.add_child(_held_draw)

	if not raid_mode:
		_build_trader()
	visible = not raid_mode
	if not raid_mode:
		open_stash()


func _small_button(text: String, pos: Vector2, sz: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 8)
	b.pressed.connect(cb)
	_root.add_child(b)
	return b


func _build_trader() -> void:
	trader_panel = TraderPanel.new()
	trader_panel.position = Vector2(410, 0)
	_root.add_child(trader_panel)
	trader_panel.setup(self)


func open_player() -> void:
	current_box = null
	other_bag = null
	other_title = ""
	visible = true
	refresh()


func open_box(box: LootBox) -> void:
	current_box = box
	other_bag = box.bag
	other_title = box.display_name() + " (przeszukiwanie...)" if box.has_hidden() else box.display_name()
	visible = true
	refresh()


func open_stash() -> void:
	current_box = null
	other_bag = Game.stash
	other_title = "SKRYTKA"
	visible = true
	refresh()


func close() -> void:
	_job = {}
	_ghosts.clear()
	_hidden.clear()
	_return_held()
	if raid_mode:
		visible = false
	current_box = null
	closed.emit()


func _return_held() -> void:
	if held == null:
		return
	var it := held
	held = null
	if held_src and _fits_anywhere(held_src, it):
		return
	if equipment.add_auto(it):
		held_src = null
		return
	if other_bag and other_bag.add_auto(it):
		return
	if Game.stash.add_auto(it):
		return
	_flash("Nie ma miejsca — przedmiot przepadł.")


func _fits_anywhere(bag: Bag, it: Item) -> bool:
	if bag.add_auto(it):
		return true
	return false


# --- odświeżanie ----------------------------------------------------------

func refresh() -> void:
	for c in _dyn.get_children():
		c.queue_free()
	_grids.clear()
	var y := 4.0
	var bag_x := 124.0
	for e in equipment.bags():
		var l := Label.new()
		l.text = String(e["name"]).substr(0, 24)
		l.position = Vector2(bag_x, y)
		l.add_theme_font_size_override("font_size", 8)
		l.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75))
		_dyn.add_child(l)
		y += 10
		var g := _make_grid(e["bag"], Vector2(bag_x, y), false)
		_dyn.add_child(g)
		y += e["bag"].h * CELL + 4
	if other_bag != null:
		var l2 := Label.new()
		l2.text = other_title
		l2.position = Vector2(244, 4)
		l2.add_theme_font_size_override("font_size", 8)
		l2.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
		_dyn.add_child(l2)
		var g2 := _make_grid(other_bag, Vector2(244, 16), current_box != null)
		_dyn.add_child(g2)
	for sv in _slot_views.values():
		sv.hidden_ref = _hidden
		sv.queue_redraw()
	if _btn_all:
		_btn_all.visible = current_box != null
	var w := equipment.total_weight()
	_weight.text = "Waga: %.1f kg (%s)\nTempo: %d%%" % [w, Equipment.LOAD_NAMES[equipment.load_level()],
		int(equipment.speed_mult() * 100)]
	if trader_panel:
		trader_panel.refresh()
	if other_bag != null and current_box != null:
		other_title = current_box.display_name() + (" (przeszukiwanie...)" if current_box.has_hidden() else "")


func _make_grid(bag: Bag, pos: Vector2, hide_hidden: bool) -> GridView:
	var g := GridView.new()
	g.position = pos
	g.hide_unrevealed = hide_hidden
	g.held_ref = func(): return held
	g.hidden_ref = _hidden
	g.set_bag(bag)
	_grids.append(g)
	g.cell_input.connect(_on_grid_input)
	g.hovered.connect(func(_v, it): _hover_item = it; _show_info(it))
	return g


func _show_info(it: Item) -> void:
	if it == null:
		_info.text = ""
		return
	if not it.revealed:
		_info.text = "Nieznany przedmiot (jeszcze przeszukujesz)"
		return
	var lines := [it.item_name()]
	var d := it.def()
	lines.append("Waga: %.2f kg   Wartość: %d" % [it.total_weight(), it.total_value()])
	if it.count > 1:
		lines.append("Ilość: %d" % it.count)
	if d.get("type", "") == "armor":
		lines.append("Klasa %d, wytrzymałość %d/%d" % [d["armor_class"], int(it.durability), int(d["durability"])])
	if d.get("type", "") == "weapon":
		var wd: Dictionary = d["weapon"]
		lines.append("Obr. %d, %d strz./min" % [wd["damage"], wd["rpm"]])
		if it.mag:
			lines.append("Magazynek: %d/%d" % [it.mag.loaded, it.mag.mag_cap()])
		else:
			lines.append("Brak magazynka (%s)" % ItemDB.get_def(d.get("mag_id", ""))["name"])
	if d.get("type", "") == "mag":
		lines.append("W środku: %d / %d (%s)" % [it.loaded, it.mag_cap(), ItemDB.get_def(it.ammo_item_id())["name"]])
		lines.append("Przeciągnij na niego amunicję, by załadować.")
	if d.get("type", "") == "ammo":
		lines.append("Penetracja: %d" % d["pen"])
	if d.get("type", "") == "container":
		lines.append("Redukcja wagi: %d%%, miejsca: %d" % [int(d["reduction"] * 100), it.bag.cell_count()])
	if d.get("type", "") == "med":
		if d.get("heal", "") == "medkit":
			lines.append("Zasób: %d HP" % int(it.durability))
		if d.get("heal", "") == "painkiller":
			lines.append("Działa na całe ciało.")
		elif raid_mode:
			lines.append("Przeciągnij na część ciała. Shift+PPM: użyj automatycznie.")
	if d.get("type", "") == "doc":
		lines.append("")
		lines.append(it.text)
	_info.text = "\n".join(lines)


func _flash(m: String) -> void:
	_msg.text = m
	_msg_t = 3.5


func _process(delta: float) -> void:
	if _msg_t > 0.0:
		_msg_t -= delta
		if _msg_t <= 0.0:
			_msg.text = ""
	if not visible:
		return
	# trzymany przedmiot goni kursor płynnie (stąd animacja podniesienia i odłożenia)
	var mp := _root.get_local_mouse_position()
	_held_pos = _held_pos.lerp(mp, 1.0 - exp(-delta * 26.0))
	_held_lift = move_toward(_held_lift, 1.0 if held != null else 0.0, delta * 9.0)
	if _body_view:
		_body_view.hint_kind = String(held.def().get("heal", "")) if held != null and held.type() == "med" else ""
	_hb.queue_redraw()
	_tick_ghosts(delta)
	_tick_job(delta)
	_held_draw.queue_redraw()


func _tick_ghosts(delta: float) -> void:
	for g in _ghosts.duplicate():
		g["t"] += delta
		if g["t"] >= g["dur"]:
			_ghosts.erase(g)
			var tgt = g.get("target")
			if tgt != null:
				_hidden.erase(tgt)
				for gv: GridView in _grids:
					if gv.bag.items.has(tgt):
						gv.flash_item(tgt, 0.18)
						gv.queue_redraw()
				for sv in _slot_views.values():
					sv.queue_redraw()
				if not g.get("bullet", false):
					Audio.play("ui_click", -10.0, 0.9 + randf() * 0.2, 0.0)


func _draw_held() -> void:
	# loty przedmiotów
	for g in _ghosts:
		if g["t"] < 0.0:
			continue
		var k: float = clampf(g["t"] / g["dur"], 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 3.0)
		var pos: Vector2 = (g["from"] as Vector2).lerp(g["to"], e)
		if g.get("bullet", false):
			pos.y -= sin(k * PI) * 10.0
			_held_draw.draw_rect(Rect2(pos - Vector2(1.5, 1.5), Vector2(3, 3)), Color(1.0, 0.85, 0.3))
			continue
		var sz: Vector2 = g["size"]
		var c: Color = g["color"]
		var scale_ := 1.0 + 0.12 * sin(k * PI)
		var r := Rect2(pos - (sz * scale_ - sz) / 2.0, sz * scale_)
		_held_draw.draw_rect(Rect2(r.position + Vector2(1, 2), r.size), Color(0, 0, 0, 0.3))
		_held_draw.draw_rect(r, Color(c.r, c.g, c.b, 0.9))
		_held_draw.draw_rect(r, Color(1, 1, 1, 0.7), false, 1.0)
	if held == null and _held_lift <= 0.0:
		return
	if held == null:
		return
	var sz2 := Vector2(held.width(), held.height()) * CELL
	var lift := _held_lift
	var tilt := clampf((_root.get_local_mouse_position().x - _held_pos.x) * 0.01, -0.12, 0.12)
	var center := _held_pos + Vector2(0, -2.0 * lift)
	var sc := 1.0 + 0.1 * lift
	_held_draw.draw_set_transform(center, tilt, Vector2(sc, sc))
	var r2 := Rect2(-sz2 / 2.0, sz2)
	_held_draw.draw_rect(Rect2(r2.position + Vector2(2, 4) * lift, r2.size), Color(0, 0, 0, 0.35 * lift))
	var c2 := held.color()
	_held_draw.draw_rect(r2, Color(c2.r, c2.g, c2.b, 0.85))
	_held_draw.draw_rect(r2, Color(1, 1, 1, 0.85), false, 1.0)
	var font := ThemeDB.fallback_font
	var txt := held.item_name().substr(0, 8)
	if held.count > 1:
		txt = "%s x%d" % [held.item_name().substr(0, 4), held.count]
	elif held.is_mag():
		txt = "Mag %d" % held.loaded
	_held_draw.draw_string(font, r2.position + Vector2(2, 9), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 1, 1))
	_held_draw.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- animacje: duchy i lokalizacja przedmiotów -------------------------------------

## Prostokąt przedmiotu na ekranie (siatki lub slot sprzętu), pusty gdy go nie widać.
func _locate(it: Item) -> Rect2:
	for g: GridView in _grids:
		if g.bag.items.has(it):
			var ir := g.item_rect(it)
			return Rect2(g.position + ir.position, ir.size)
	for sv in _slot_views.values():
		if equipment.get_slot(sv.slot) == it:
			return Rect2(sv.position + Vector2(2, 11), Vector2(sv.size.x - 4, sv.size.y - 13))
	return Rect2()


## Dodaje ducha lecącego do przedmiotu `it` (po zmianie i odświeżeniu); `it` jest ukryty do lądowania.
func _place_fx(it: Item, from: Vector2, delay: float = 0.0) -> void:
	var r := _locate(it)
	if r.size == Vector2.ZERO:
		return
	_hidden[it] = true
	for g: GridView in _grids:
		g.queue_redraw()
	for sv in _slot_views.values():
		sv.hidden_ref = _hidden
		sv.queue_redraw()
	var size := Vector2(it.width(), it.height()) * CELL
	_ghosts.append({"from": from, "to": r.position, "t": -delay, "dur": FLY_TIME, "size": size,
		"color": it.color(), "target": it})


## Pozycje wszystkich widocznych przedmiotów (do animowania przemieszczeń po sortowaniu itp.).
func _snapshot() -> Dictionary:
	var out := {}
	for g: GridView in _grids:
		for it: Item in g.bag.items:
			out[it] = _locate(it).position
	return out


func _animate_from(snap: Dictionary, stagger: float = 0.0) -> void:
	var i := 0
	for it in snap:
		var r := _locate(it)
		if r.size == Vector2.ZERO:
			continue
		if (r.position - snap[it]).length() > 1.0:
			_place_fx(it, snap[it], minf(i * stagger, 0.4))
			i += 1


func _bullet_fx(from: Vector2, to: Vector2) -> void:
	_ghosts.append({"from": from, "to": to, "t": 0.0, "dur": 0.11, "bullet": true})


# --- ładowanie magazynków --------------------------------------------------------

func _start_load_all() -> void:
	if not _job.is_empty():
		_job = {}
		return
	if not _can_load_any():
		_flash("Brak luźnej amunicji pasującej do pustych magazynków.")
		Audio.play("ui_deny")
		return
	_job = {"kind": "all", "t": 0.0}
	_flash("Ładowanie magazynków... (klik przerywa)")


func _can_load_any() -> bool:
	for e in equipment.bags():
		if e["slot"] == "secure":
			continue
		for it: Item in e["bag"].items:
			if it.is_mag() and it.loaded < it.mag_cap() and equipment.count_of(it.ammo_item_id()) > 0:
				return true
	return false


func _start_load_held(mag: Item) -> void:
	_job = {"kind": "held", "mag": mag, "t": 0.0}
	_flash("Ładowanie... (klik przerywa)")


func _tick_job(delta: float) -> void:
	if _job.is_empty():
		return
	_job["t"] -= delta
	if _job["t"] > 0.0:
		return
	_job["t"] = LOAD_TICK
	match _job["kind"]:
		"all":
			var from_r := Rect2()
			var m := equipment.load_step()
			if m == null:
				_end_job("Magazynki załadowane.")
				return
			from_r = _find_ammo_rect(m.ammo_item_id())
			_after_load_tick(m, from_r.get_center() if from_r.size != Vector2.ZERO else Vector2.ZERO)
		"held":
			var mag: Item = _job["mag"]
			if mag == null or held == null or held.type() != "ammo" or held.def().get("ammo_type") != mag.def().get("ammo_type") \
					or mag.loaded >= mag.mag_cap() or _locate(mag).size == Vector2.ZERO:
				_end_job("")
				return
			held.count -= 1
			mag.loaded += 1
			var origin := _held_pos
			if held.count <= 0:
				held = null
			_after_load_tick(mag, origin)
			if mag.loaded >= mag.mag_cap() or held == null:
				_end_job("Magazynek pełny." if mag.loaded >= mag.mag_cap() else "")


func _after_load_tick(mag: Item, origin: Vector2) -> void:
	var r := _locate(mag)
	if r.size != Vector2.ZERO:
		if origin != Vector2.ZERO:
			_bullet_fx(origin, r.get_center())
		for g: GridView in _grids:
			if g.bag.items.has(mag):
				g.flash_item(mag, 0.12)
	Audio.play("ammo_tick", -9.0, 0.85 + 0.35 * float(mag.loaded) / maxf(1.0, mag.mag_cap()), 0.02)
	for g: GridView in _grids:
		g.queue_redraw()
	_weight.text = "Waga: %.1f kg (%s)\nTempo: %d%%" % [equipment.total_weight(),
		Equipment.LOAD_NAMES[equipment.load_level()], int(equipment.speed_mult() * 100)]


func _end_job(msg: String) -> void:
	_job = {}
	if msg != "":
		_flash(msg)
		Audio.play("reload_end", -8.0)
	_after_change()


func _find_ammo_rect(ammo_id: String) -> Rect2:
	for g: GridView in _grids:
		for it: Item in g.bag.items:
			if it.id == ammo_id:
				var ir := g.item_rect(it)
				return Rect2(g.position + ir.position, ir.size)
	return Rect2()


# --- sortowanie i „weź wszystko" --------------------------------------------------

func _sort_all() -> void:
	var snap := _snapshot()
	for e in equipment.bags():
		e["bag"].repack()
	if other_bag != null and current_box == null:
		other_bag.repack()
	_after_change()
	_animate_from(snap, 0.012)
	Audio.play("ui_click", -6.0)
	_flash("Posortowano.")


func _take_all() -> void:
	if other_bag == null or current_box == null:
		return
	var snap := _snapshot()
	var moved: Array = []
	var failed := 0
	for it: Item in other_bag.items.duplicate():
		if not it.revealed:
			continue
		other_bag.remove(it)
		if equipment.add_auto(it, it.type() in ["ammo", "med", "mag"]):
			moved.append(it)
		else:
			other_bag.items.append(it)
			failed += 1
	_after_change()
	var i := 0
	for it in moved:
		var from: Vector2 = snap.get(it, Vector2(244, 16))
		_place_fx(it, from, minf(i * 0.035, 0.5))
		i += 1
	if failed > 0:
		_flash("Zabrano %d, %d nie mieści się." % [moved.size(), failed])
	elif moved.size() > 0:
		_flash("Zabrano wszystko (%d)." % moved.size())


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and not _job.is_empty():
		var was_held_job: bool = _job["kind"] == "held"
		_end_job("")
		if was_held_job and held != null:
			pass
	if event is InputEventKey and event.pressed and not event.echo:
		var kc: int = event.physical_keycode
		if kc >= KEY_1 and kc <= KEY_9 and _hover_item != null and _hover_item.type() == "med":
			_bind_hotbar(kc - KEY_1, _hover_item.id)
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_V:
			_start_load_all()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_R and held != null:
			held.rotated = not held.rotated
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_ESCAPE and raid_mode:
			close()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_TAB and raid_mode:
			close()
			get_viewport().set_input_as_handled()


# --- obsługa kliknięć -----------------------------------------------------

func _after_change() -> void:
	if player:
		player.equipment_changed()
	refresh()


func _is_player_bag(b: Bag) -> bool:
	for e in equipment.bags():
		if e["bag"] == b:
			return true
	return false


func _on_grid_input(view: GridView, cell: Vector2i, ev: InputEventMouseButton) -> void:
	var bag := view.bag
	if ev.button_index == MOUSE_BUTTON_LEFT:
		if held == null:
			var it := bag.item_at(cell.x, cell.y)
			if it and it.revealed:
				_held_pos = _locate(it).get_center() if _locate(it).size != Vector2.ZERO else _held_pos
				if ev.shift_pressed and it.count > 1:
					# Shift+LPM: weź połowę stosu
					var n := it.count / 2
					it.count -= n
					var part := Item.from_dict(it.to_dict())
					part.count = n
					held = part
					held_src = bag
					Audio.play("ui_click", -9.0, 1.1, 0.0)
					refresh()
					return
				bag.remove(it)
				held = it
				held_src = bag
				Audio.play("ui_click", -10.0, 1.2, 0.0)
				refresh()
		else:
			_drop(view, cell)
	elif ev.button_index == MOUSE_BUTTON_RIGHT:
		if held != null:
			held.rotated = not held.rotated
			view.queue_redraw()
		else:
			var it2 := bag.item_at(cell.x, cell.y)
			if it2 and it2.revealed:
				if ev.shift_pressed and it2.type() == "med" and raid_mode and player != null and _is_player_bag(bag):
					var msg := player.start_use(it2.id)
					if msg != "":
						_flash(msg)
						Audio.play("ui_deny", -8.0)
					return
				_quick_action(bag, it2)


func _drop(view: GridView, cell: Vector2i) -> void:
	var bag := view.bag
	if held.bag == bag:
		_flash("Nie wsadzisz pojemnika do samego siebie.")
		return
	var target := bag.item_at(cell.x, cell.y)
	# amunicja na magazynek: animowane ładowanie naboi
	if held.type() == "ammo" and target != null and target.is_mag():
		if target.def().get("ammo_type") != held.def().get("ammo_type"):
			_flash("Ten magazynek jest do innej amunicji.")
			Audio.play("ui_deny")
		elif target.loaded >= target.mag_cap():
			_flash("Magazynek jest pełny.")
		else:
			_start_load_held(target)
		return
	var tl := view.held_top_left(held, cell)
	var from := _held_pos - Vector2(held.width(), held.height()) * CELL / 2.0
	if bag.fits(held, tl.x, tl.y):
		var placed := held
		bag.place(held, tl.x, tl.y)
		held = null
		_after_change()
		_place_fx(placed, from)
		return
	if target and target != held and target.id == held.id and held.stack_max() > 1:
		var room := target.stack_max() - target.count
		var moved := mini(room, held.count)
		if moved > 0:
			target.count += moved
			held.count -= moved
			if held.count <= 0:
				held = null
			Audio.play("ui_click", -9.0, 1.0, 0.0)
			_after_change()
			for g: GridView in _grids:
				if g.bag == bag:
					g.flash_item(target, 0.2)
			return
	# zamiana z jednym przedmiotem
	var overlapped: Array = []
	for o in bag.items:
		if tl.x < o.x + o.width() and tl.x + held.width() > o.x and tl.y < o.y + o.height() and tl.y + held.height() > o.y:
			overlapped.append(o)
	if overlapped.size() == 1:
		var o: Item = overlapped[0]
		var o_pos := _locate(o).get_center()
		bag.remove(o)
		if bag.fits(held, tl.x, tl.y):
			var placed2 := held
			bag.place(held, tl.x, tl.y)
			held = o
			held_src = bag
			_held_pos = o_pos
			_after_change()
			_place_fx(placed2, from)
			return
		bag.items.append(o)
	_flash("Nie mieści się tutaj.")
	Audio.play("ui_deny", -8.0)


func _quick_action(bag: Bag, it: Item) -> void:
	var from_r := _locate(it)
	var from := from_r.position if from_r.size != Vector2.ZERO else _held_pos
	if not _is_player_bag(bag):
		# z łupu/skrytki do ekwipunku
		bag.remove(it)
		var quick := it.type() in ["ammo", "med", "mag"]
		if equipment.add_auto(it, quick):
			_after_change()
			_place_fx(it, from)
		else:
			bag.items.append(it)
			_flash("Brak miejsca w ekwipunku.")
			Audio.play("ui_deny", -8.0)
		return
	var slot: String = it.def().get("slot", "")
	if slot != "" and slot in Equipment.SLOTS:
		bag.remove(it)
		var prev := equipment.equip(slot, it)
		if prev:
			if not (bag.add_auto(prev) or equipment.add_auto(prev) or (other_bag != null and other_bag.add_auto(prev))):
				equipment.equip(slot, prev)
				bag.items.append(it)
				_flash("Brak miejsca na zdjęty przedmiot.")
				return
		_after_change()
		_place_fx(it, from)
		if prev:
			_place_fx(prev, _slot_pos(slot))
		return
	# magazynek do wolnej broni bez magazynka: szybkie włożenie
	if it.is_mag():
		for s in ["primary", "pistol"]:
			var w := equipment.get_slot(s)
			if w and w.mag == null and w.def().get("mag_id", "") == it.id:
				bag.remove(it)
				w.mag = it
				Audio.play("reload_end", -6.0)
				_after_change()
				return
	# przenieś do drugiego pojemnika
	if other_bag != null and not (current_box and current_box.is_corpse and false):
		bag.remove(it)
		if other_bag.add_auto(it):
			_after_change()
			_place_fx(it, from)
		else:
			bag.items.append(it)
			_flash("Brak miejsca w drugim pojemniku.")


func _slot_pos(slot: String) -> Vector2:
	var sv = _slot_views.get(slot)
	return (sv.position + Vector2(2, 11)) if sv else _held_pos


func _on_slot_input(view: SlotView, ev: InputEventMouseButton) -> void:
	var slot := view.slot
	var w := equipment.get_slot(slot)
	if ev.button_index == MOUSE_BUTTON_LEFT:
		if held == null:
			var it := equipment.unequip(slot)
			if it:
				_held_pos = view.position + view.size / 2.0
				held = it
				held_src = null
				Audio.play("ui_click", -10.0, 1.2, 0.0)
				_after_change()
		else:
			# magazynek na broń: wymiana magazynka
			if w != null and held.is_mag() and held.id == w.def().get("mag_id", ""):
				var old := w.mag
				w.mag = held
				held = old
				held_src = null
				Audio.play("reload_end", -5.0)
				_after_change()
				return
			if held.type() == "ammo" and w != null:
				_flash("Załaduj amunicję do magazynka, nie do broni.")
				return
			if equipment.accepts(slot, held):
				var from := _held_pos - Vector2(held.width(), held.height()) * CELL / 2.0
				var placed := held
				var prev := equipment.equip(slot, held)
				held = prev
				held_src = null
				if prev:
					_held_pos = view.position + view.size / 2.0
				_after_change()
				_place_fx(placed, from)
			else:
				_flash("To nie pasuje do tego miejsca.")
				Audio.play("ui_deny", -8.0)
	elif ev.button_index == MOUSE_BUTTON_RIGHT and held == null:
		if ev.shift_pressed and w != null and w.mag != null:
			# Shift+PPM: wyjmij magazynek z broni
			var m := w.mag
			w.mag = null
			if equipment.add_auto(m, true) or (other_bag != null and other_bag.add_auto(m)):
				Audio.play("reload_start", -8.0)
				_after_change()
				_place_fx(m, view.position + Vector2(2, 11))
			else:
				w.mag = m
				_flash("Brak miejsca na magazynek.")
			return
		var it2 := equipment.unequip(slot)
		if it2:
			if equipment.add_auto(it2) or (other_bag != null and other_bag.add_auto(it2)):
				_after_change()
				_place_fx(it2, view.position + Vector2(2, 11))
			else:
				equipment.equip(slot, it2)
				_flash("Brak miejsca.")


# --- ciało i pasek szybkiego dostępu ----------------------------------------------

func _on_body_hover(part: int) -> void:
	if part < 0:
		_info.text = ""
		return
	var b := player.body
	var lines := ["%s: %d/%d HP" % [Body.PART_NAMES[part], int(ceil(b.hp[part])), int(b.max_hp[part])]]
	for f in b.status_flags(part):
		lines.append(f)
	if b.max_hp[part] < Body.MAX_HP[part] - 0.5:
		lines.append("Po operacji: maks. %d HP" % int(b.max_hp[part]))
	_info.text = "\n".join(lines)


func _on_body_input(part: int, ev: InputEventMouseButton) -> void:
	if ev.button_index != MOUSE_BUTTON_LEFT or player == null:
		return
	if held == null:
		return
	if held.type() != "med":
		_flash("To nie jest środek medyczny.")
		return
	var it := held
	if it.def().get("heal", "") == "painkiller":
		part = -1
	# środek musi być w ekwipunku gracza (zabieg zużywa go z plecaka/kieszeni)
	held = null
	if not _is_player_item(it):
		if not equipment.add_auto(it):
			held = it
			_flash("Brak miejsca w ekwipunku na ten środek.")
			return
	else:
		_return_held_item(it)
	_after_change()
	var msg := player.start_use(it.id, part)
	if msg != "":
		_flash(msg)
		Audio.play("ui_deny", -8.0)
	else:
		_flash("Zabieg: %s" % ("całe ciało" if part < 0 else Body.PART_NAMES[part]))


func _is_player_item(it: Item) -> bool:
	for e in equipment.bags():
		if (e["bag"] as Bag).items.has(it):
			return true
	return false


func _return_held_item(it: Item) -> void:
	if held_src and held_src.add_auto(it):
		return
	if not equipment.add_auto(it):
		if other_bag == null or not other_bag.add_auto(it):
			Game.stash.add_auto(it)


func _bind_hotbar(slot: int, id: String) -> void:
	for i in Game.HOTBAR_SIZE:
		if Game.hotbar[i] == id:
			Game.hotbar[i] = ""
	Game.hotbar[slot] = id
	Audio.play("ui_click", -6.0, 1.3, 0.0)
	_flash("Przypisano do [%d]: %s" % [slot + 1, ItemDB.get_def(id).get("name", id)])


func _draw_hotbar() -> void:
	var font := ThemeDB.fallback_font
	for i in Game.HOTBAR_SIZE:
		var r := Rect2(i * 24.0, 0, 22, 22)
		_hb.draw_rect(r, Color(0.1, 0.11, 0.13))
		var hot := i == _hb_hover or (held != null and held.type() == "med" and i == _hb_hover)
		_hb.draw_rect(r, Color(1, 1, 1) if hot else Color(0.35, 0.37, 0.42), false, 1.0)
		_hb.draw_string(font, r.position + Vector2(2, 7), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0.7, 0.75, 0.8))
		var id: String = Game.hotbar[i]
		if id == "":
			continue
		var d := ItemDB.get_def(id)
		var n := equipment.count_of(id) + (Game.stash.count_of(id) if not raid_mode else 0)
		var c: Color = d.get("color", Color(0.6, 0.6, 0.6))
		if n <= 0:
			c = c.darkened(0.6)
		var ir := Rect2(r.position + Vector2(4, 7), Vector2(14, 12))
		_hb.draw_rect(ir, c.darkened(0.2))
		_hb.draw_rect(ir, c.lightened(0.15), false, 1.0)
		_hb.draw_string(font, ir.position + Vector2(1, 8), String(d.get("name", id)).substr(0, 3), HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(1, 1, 1))


func _on_hotbar_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hb_hover = int(event.position.x / 24.0) if event.position.x >= 0 else -1
		if _hb_hover >= Game.HOTBAR_SIZE:
			_hb_hover = -1
	elif event is InputEventMouseButton and event.pressed:
		var i := int(event.position.x / 24.0)
		if i < 0 or i >= Game.HOTBAR_SIZE:
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			Game.hotbar[i] = ""
			Audio.play("ui_click", -8.0, 0.8, 0.0)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if held != null and held.type() == "med":
				_bind_hotbar(i, held.id)
			elif held != null:
				_flash("Na pasku mogą być tylko środki medyczne.")
