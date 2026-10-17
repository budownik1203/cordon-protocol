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
var _trader_box: VBoxContainer
var _money_label: Label
var _msg_t: float = 0.0
var _stock := ["bandage", "hemostatic", "splint", "painkiller", "ammo_9", "ammo_556", "pistol_p9", "smg_kr",
	"rifle_skm", "helmet_2", "helmet_3", "armor_3", "armor_4", "rig_a", "rig_b", "belt_a", "backpack_a",
	"backpack_b", "lamp"]


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
	bg.color = Color(0.05, 0.06, 0.07, 0.96)
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
	_info.position = Vector2(6, 196)
	_info.size = Vector2(112, 150)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_font_size_override("font_size", 8)
	_info.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	_root.add_child(_info)

	_dyn = Control.new()
	_root.add_child(_dyn)

	_msg = Label.new()
	_msg.position = Vector2(124, 346)
	_msg.add_theme_font_size_override("font_size", 8)
	_msg.add_theme_color_override("font_color", Color(1, 0.7, 0.4))
	_root.add_child(_msg)

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


func _build_trader() -> void:
	var t := Label.new()
	t.text = "HANDLARZ (kup: klik)"
	t.position = Vector2(412, 4)
	t.add_theme_font_size_override("font_size", 8)
	_root.add_child(t)
	_money_label = Label.new()
	_money_label.position = Vector2(412, 16)
	_money_label.add_theme_font_size_override("font_size", 8)
	_money_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.4))
	_root.add_child(_money_label)
	var sc := ScrollContainer.new()
	sc.position = Vector2(412, 28)
	sc.size = Vector2(222, 270)
	_root.add_child(sc)
	_trader_box = VBoxContainer.new()
	_trader_box.add_theme_constant_override("separation", 1)
	sc.add_child(_trader_box)
	for id in _stock:
		var d := ItemDB.get_def(id)
		var price := int(d["value"] * 1.25)
		var b := Button.new()
		b.text = "%s — %d" % [d["name"].substr(0, 34), price]
		b.add_theme_font_size_override("font_size", 8)
		b.custom_minimum_size = Vector2(205, 14)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_buy.bind(id, price))
		b.mouse_entered.connect(func(): _show_info(Item.new(id)))
		_trader_box.add_child(b)
	var sell := Button.new()
	sell.text = "SPRZEDAJ trzymany (55%)"
	sell.position = Vector2(412, 304)
	sell.size = Vector2(222, 22)
	sell.add_theme_font_size_override("font_size", 8)
	sell.pressed.connect(_sell_held)
	_root.add_child(sell)


func _buy(id: String, price: int) -> void:
	if Game.money < price:
		_flash("Za mało bonów.")
		return
	var qty := 1
	var d := ItemDB.get_def(id)
	if d.get("type", "") == "ammo":
		qty = 30
		price = int(d["value"] * 1.25) * 30
		if Game.money < price:
			_flash("Za mało bonów (30 szt.).")
			return
	var it := Item.new(id, qty)
	if d.get("type", "") == "weapon":
		it.loaded = 0
	if not Game.stash.add_auto(it):
		_flash("Skrytka pełna.")
		return
	Game.money -= price
	_flash("Kupiono: %s" % it.item_name())
	refresh()


func _sell_held() -> void:
	if held == null:
		_flash("Weź przedmiot do ręki, potem kliknij Sprzedaj.")
		return
	var v := int(held.total_value() * 0.55)
	Game.money += v
	_flash("Sprzedano %s za %d bonów." % [held.item_name(), v])
	held = null
	held_src = null
	refresh()


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
		sv.queue_redraw()
	var w := equipment.total_weight()
	_weight.text = "Waga: %.1f kg (%s)\nTempo: %d%%" % [w, Equipment.LOAD_NAMES[equipment.load_level()],
		int(equipment.speed_mult() * 100)]
	if _money_label:
		_money_label.text = "Bony: %d" % Game.money
	if other_bag != null and current_box != null:
		other_title = current_box.display_name() + (" (przeszukiwanie...)" if current_box.has_hidden() else "")


func _make_grid(bag: Bag, pos: Vector2, hide_hidden: bool) -> GridView:
	var g := GridView.new()
	g.position = pos
	g.hide_unrevealed = hide_hidden
	g.held_ref = func(): return held
	g.set_bag(bag)
	g.cell_input.connect(_on_grid_input)
	g.hovered.connect(func(_v, it): _show_info(it))
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
		lines.append("Obr. %d, %d strz./min, magazynek %d (w środku %d)" % [wd["damage"], wd["rpm"], wd["mag"], it.loaded])
	if d.get("type", "") == "ammo":
		lines.append("Penetracja: %d" % d["pen"])
	if d.get("type", "") == "container":
		lines.append("Redukcja wagi: %d%%, miejsca: %d" % [int(d["reduction"] * 100), it.bag.cell_count()])
	if d.get("type", "") == "doc":
		lines.append("")
		lines.append(it.text)
	_info.text = "\n".join(lines)


func _flash(m: String) -> void:
	_msg.text = m
	_msg_t = 3.0


func _process(delta: float) -> void:
	if _msg_t > 0.0:
		_msg_t -= delta
		if _msg_t <= 0.0:
			_msg.text = ""
	if visible:
		_held_draw.queue_redraw()


func _draw_held() -> void:
	if held == null:
		return
	var mp := _root.get_local_mouse_position()
	var r := Rect2(mp - Vector2(held.width(), held.height()) * CELL / 2.0, Vector2(held.width(), held.height()) * CELL)
	var c := held.color()
	_held_draw.draw_rect(r, Color(c.r, c.g, c.b, 0.75))
	_held_draw.draw_rect(r, Color(1, 1, 1, 0.8), false, 1.0)
	_held_draw.draw_string(ThemeDB.fallback_font, r.position + Vector2(2, 9), held.item_name().substr(0, 8),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 1, 1))


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_R and held != null:
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
				bag.remove(it)
				held = it
				held_src = bag
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
				_quick_action(bag, it2)


func _drop(view: GridView, cell: Vector2i) -> void:
	var bag := view.bag
	if held.bag == bag:
		_flash("Nie wsadzisz pojemnika do samego siebie.")
		return
	var tl := view.held_top_left(held, cell)
	if bag.fits(held, tl.x, tl.y):
		bag.place(held, tl.x, tl.y)
		held = null
		_after_change()
		return
	var target := bag.item_at(cell.x, cell.y)
	if target and target != held and target.id == held.id and held.stack_max() > 1:
		var room := target.stack_max() - target.count
		var moved := mini(room, held.count)
		if moved > 0:
			target.count += moved
			held.count -= moved
			if held.count <= 0:
				held = null
			_after_change()
			return
	# zamiana z jednym przedmiotem
	var overlapped: Array = []
	for o in bag.items:
		if tl.x < o.x + o.width() and tl.x + held.width() > o.x and tl.y < o.y + o.height() and tl.y + held.height() > o.y:
			overlapped.append(o)
	if overlapped.size() == 1:
		var o: Item = overlapped[0]
		bag.remove(o)
		if bag.fits(held, tl.x, tl.y):
			bag.place(held, tl.x, tl.y)
			held = o
			held_src = bag
			_after_change()
			return
		bag.items.append(o)
	_flash("Nie mieści się tutaj.")


func _quick_action(bag: Bag, it: Item) -> void:
	if not _is_player_bag(bag):
		# z łupu/skrytki do ekwipunku
		bag.remove(it)
		var quick := it.type() in ["ammo", "med"]
		if equipment.add_auto(it, quick):
			_after_change()
		else:
			bag.items.append(it)
			_flash("Brak miejsca w ekwipunku.")
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
		return
	# przenieś do drugiego pojemnika
	if other_bag != null and not (current_box and current_box.is_corpse and false):
		bag.remove(it)
		if other_bag.add_auto(it):
			_after_change()
		else:
			bag.items.append(it)
			_flash("Brak miejsca w drugim pojemniku.")


func _on_slot_input(view: SlotView, ev: InputEventMouseButton) -> void:
	var slot := view.slot
	if ev.button_index == MOUSE_BUTTON_LEFT:
		if held == null:
			var it := equipment.unequip(slot)
			if it:
				held = it
				held_src = null
				_after_change()
		else:
			if equipment.accepts(slot, held):
				var prev := equipment.equip(slot, held)
				held = prev
				held_src = null
				_after_change()
			else:
				_flash("To nie pasuje do tego miejsca.")
	elif ev.button_index == MOUSE_BUTTON_RIGHT and held == null:
		var it2 := equipment.unequip(slot)
		if it2:
			if equipment.add_auto(it2) or (other_bag != null and other_bag.add_auto(it2)):
				_after_change()
			else:
				equipment.equip(slot, it2)
				_flash("Brak miejsca.")
