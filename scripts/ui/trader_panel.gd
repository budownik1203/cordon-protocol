class_name TraderPanel
extends Control
## Panel handlarzy w bazie: trzy zakładki (Wójt, Ruda, Sznurek), wypowiedzi zależne od przebiegu gry,
## kupno/sprzedaż, ubezpieczenie, zadania z wyborem nagrody.

const W := 228.0
const MARKUP := {"kw": 1.25, "med": 1.2, "pos": 1.35}
const SHORT := {"kw": "Wójt", "med": "Ruda", "pos": "Sznurek"}

var ui: InventoryUI
var trader: String = "kw"
var _tabs: Dictionary = {}
var _name_l: Label
var _speech: Label
var _money: Label
var _list: VBoxContainer
var _scroll: ScrollContainer
var _insure_btn: Button
var _quest_btn: Button
var _overlay: Control = null


func setup(p_ui: InventoryUI) -> void:
	ui = p_ui
	size = Vector2(W, 360)
	var x := 0.0
	for t in Dialogue.ORDER:
		var b := Button.new()
		b.text = SHORT[t]
		b.position = Vector2(x, 2)
		b.size = Vector2(74, 16)
		b.add_theme_font_size_override("font_size", 8)
		b.pressed.connect(select.bind(t))
		add_child(b)
		_tabs[t] = b
		x += 77.0
	_name_l = _label(Vector2(0, 21), Vector2(W, 10), Color(0.95, 0.85, 0.45))
	_speech = _label(Vector2(0, 32), Vector2(W, 38), Color(0.78, 0.82, 0.86))
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech.custom_minimum_size = Vector2(W, 38)
	_money = _label(Vector2(0, 70), Vector2(W, 10), Color(0.9, 0.85, 0.4))
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(0, 82)
	_scroll.size = Vector2(W, 200)
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 1)
	_scroll.add_child(_list)
	var sell := _button("SPRZEDAJ trzymany", Vector2(0, 286), Vector2(W, 22), _sell_held)
	sell.tooltip_text = "Weź przedmiot LPM, potem kliknij. Każdy handlarz skupuje inne rzeczy."
	_insure_btn = _button("UBEZPIECZ trzymany", Vector2(0, 310), Vector2(112, 22), _insure_held)
	_quest_btn = _button("ZADANIE", Vector2(116, 310), Vector2(112, 22), _open_quest)
	select("kw", true)


func _label(pos: Vector2, sz: Vector2, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", col)
	add_child(l)
	return l


func _button(text: String, pos: Vector2, sz: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.add_theme_font_size_override("font_size", 8)
	b.pressed.connect(cb)
	add_child(b)
	return b


func _stock() -> Array:
	var kompleks := Game.is_unlocked("kompleks")
	match trader:
		"kw":
			var s := ["pistol_p9", "smg_kr", "rifle_skm", "ammo_9", "ammo_556", "helmet_2", "helmet_3", "armor_3",
				"armor_4", "rig_a", "rig_b", "belt_a", "backpack_a", "backpack_b"]
			if kompleks:
				s.append_array(["dmr_sw", "ammo_762", "helmet_4", "armor_5"])
			return s
		"med":
			return ["bandage", "hemostatic", "splint", "painkiller"]
		_:
			return ["lamp", "battery", "tape", "watch", "radio", "key_exit"]


func price_of(id: String) -> int:
	var d := ItemDB.get_def(id)
	var p := int(d["value"] * MARKUP[trader])
	if id == "key_exit":
		p = int(d["value"] * 2.5)
	return p


## Stawka skupu (0 = nie skupuje).
func sell_rate(it: Item) -> float:
	var t := it.type()
	match trader:
		"kw":
			if t in ["weapon", "armor", "container", "ammo"]:
				return 0.55
		"med":
			if t == "med":
				return 0.6
			if it.id == "sample":
				return 0.9
			if t == "doc":
				return 0.7
		"pos":
			if it.id == "sample":
				return 0.7
			if t in ["loot", "doc", "key"]:
				return 0.75
	return 0.0


func select(t: String, with_line: bool = true) -> void:
	trader = t
	for k in _tabs:
		(_tabs[k] as Button).disabled = k == t
	var info: Dictionary = Dialogue.TRADERS[t]
	_name_l.text = "%s — %s" % [info["name"], info["role"]]
	_rebuild_list()
	if with_line:
		say(_greeting_ctx())
	refresh()
	_close_overlay()


func _greeting_ctx() -> String:
	var ctx: String = Game.last_ctx if Game.last_ctx != "" else "greet"
	if ctx == "kill_szab" and trader != "pos" and trader != "med":
		ctx = "after_extract"
	if Game.corpse.size() > 0 and randf() < 0.35:
		ctx = "corpse"
	return ctx


func say(ctx: String) -> void:
	_speech.text = "„%s”" % Dialogue.line(trader, ctx)


func _rebuild_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	for id in _stock():
		var d := ItemDB.get_def(id)
		var price := price_of(id)
		if d.get("type", "") == "ammo":
			price *= 30
		var b := Button.new()
		b.text = "%s — %d%s" % [String(d["name"]).substr(0, 32), price, " (x30)" if d.get("type", "") == "ammo" else ""]
		b.add_theme_font_size_override("font_size", 8)
		b.custom_minimum_size = Vector2(W - 16, 14)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_buy.bind(id))
		b.mouse_entered.connect(func(): ui._show_info(Item.new(id)))
		_list.add_child(b)


func refresh() -> void:
	_money.text = "Bony: %d     Poczta: %d" % [Game.money, Game.mail_waiting()]
	_insure_btn.visible = trader == "kw"
	_quest_btn.size.x = 112.0 if trader == "kw" else W
	_quest_btn.position.x = 116.0 if trader == "kw" else 0.0
	for t in _tabs:
		var mark := ""
		var q := Game.current_quest(t)
		if not q.is_empty():
			if Game.quest_ready(q["id"]):
				mark = " !"
			elif Game.quest_state(q["id"]) == "":
				mark = " *"
		(_tabs[t] as Button).text = SHORT[t] + mark
	var cq := Game.current_quest(trader)
	if cq.is_empty():
		_quest_btn.text = "Zadania: brak"
	elif Game.quest_ready(cq["id"]):
		_quest_btn.text = "ZADANIE: ODBIERZ!"
	elif Game.quest_state(cq["id"]) == "active":
		_quest_btn.text = "ZADANIE (w toku)"
	else:
		_quest_btn.text = "ZADANIE (nowe)"


# --- handel -----------------------------------------------------------------

func _buy(id: String) -> void:
	var d := ItemDB.get_def(id)
	var qty := 1
	var price := price_of(id)
	if d.get("type", "") == "ammo":
		qty = 30
		price *= 30
	if Game.money < price:
		say("no_money")
		Audio.play("ui_deny")
		ui._flash("Za mało bonów.")
		return
	var it := Item.new(id, qty)
	if d.get("type", "") == "weapon":
		it.loaded = 0
	if not Game.stash.add_auto(it):
		say("no_room")
		Audio.play("ui_deny")
		ui._flash("Skrytka pełna.")
		return
	Game.money -= price
	Audio.play("ui_buy", -2.0)
	say("buy")
	ui._flash("Kupiono: %s" % it.item_name())
	ui.refresh()


func _sell_held() -> void:
	var h: Item = ui.held
	if h == null:
		say("empty_hand")
		ui._flash("Weź przedmiot do ręki, potem kliknij Sprzedaj.")
		return
	var rate := sell_rate(h)
	if rate <= 0.0:
		say("refuse")
		Audio.play("ui_deny")
		ui._flash("%s tego nie skupuje." % Dialogue.TRADERS[trader]["name"])
		return
	var v := int(h.total_value() * rate)
	Game.money += v
	Audio.play("ui_sell", -2.0)
	say("sell")
	ui._flash("Sprzedano %s za %d bonów (%d%%)." % [h.item_name(), v, int(rate * 100)])
	ui.held = null
	ui.held_src = null
	ui.refresh()


func _insure_held() -> void:
	var h: Item = ui.held
	if h == null:
		say("empty_hand")
		ui._flash("Weź do ręki broń, pancerz lub plecak, potem kliknij Ubezpiecz.")
		return
	if not (h.type() in ["weapon", "armor", "container"]) or h.def().get("slot", "") == "secure":
		say("insure_no")
		Audio.play("ui_deny")
		ui._flash("Tego nie da się ubezpieczyć.")
		return
	if h.insured:
		say("already")
		return
	var cost := int(h.unit_value() * Game.INSURE_RATE)
	if Game.money < cost:
		say("no_money")
		Audio.play("ui_deny")
		ui._flash("Polisa kosztuje %d bonów." % cost)
		return
	Game.money -= cost
	h.insured = true
	Audio.play("ui_buy", -2.0)
	say("insure_ok")
	ui._flash("Ubezpieczono %s za %d bonów. Po śmierci wraca pocztą (75%%), bez zawartości." % [h.item_name(), cost])
	ui.refresh()


# --- zadania ------------------------------------------------------------------

func _close_overlay() -> void:
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null


func _open_quest() -> void:
	_close_overlay()
	var q := Game.current_quest(trader)
	if q.is_empty():
		say("quest_none")
		ui._flash("Ten handlarz nie ma więcej zadań.")
		return
	_overlay = Control.new()
	_overlay.position = Vector2(0, 82)
	_overlay.size = Vector2(W, 200)
	add_child(_overlay)
	var bg := ColorRect.new()
	bg.size = _overlay.size
	bg.color = Color(0.08, 0.09, 0.11, 0.98)
	_overlay.add_child(bg)
	var state := Game.quest_state(q["id"])
	var text: String = q["text"]
	if q.has("alt") and Game.previous_choice(trader) == 1:
		text = q["alt"]
	var t := Label.new()
	t.text = "%s\n\n%s" % [q["title"].to_upper(), text]
	t.position = Vector2(4, 4)
	t.custom_minimum_size = Vector2(W - 8, 90)
	t.size = Vector2(W - 8, 90)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_theme_font_size_override("font_size", 8)
	_overlay.add_child(t)
	var y := 94.0
	if state == "":
		say("quest_new")
		_ov_button("Przyjmij zadanie", Vector2(4, y), Vector2(W - 8, 18), func():
			Game.accept_quest(q["id"])
			Audio.play("pickup", -4.0)
			_open_quest()
			refresh())
	else:
		var pr := Game.quest_progress(q["id"])
		var pl := Label.new()
		pl.text = "Postęp: %d / %d   %s" % [pr[0], pr[1], _goal_text(q)]
		pl.position = Vector2(4, y)
		pl.custom_minimum_size = Vector2(W - 8, 20)
		pl.size = Vector2(W - 8, 20)
		pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pl.add_theme_font_size_override("font_size", 8)
		pl.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6) if Game.quest_ready(q["id"]) else Color(0.9, 0.8, 0.5))
		_overlay.add_child(pl)
		y += 24.0
		if Game.quest_ready(q["id"]):
			say("quest_done")
			var lbl := Label.new()
			lbl.text = "Wybierz nagrodę (jedną):"
			lbl.position = Vector2(4, y)
			lbl.add_theme_font_size_override("font_size", 8)
			_overlay.add_child(lbl)
			y += 12.0
			for i in 2:
				var label: String = q["rewards"][i]["label"]
				var b := _ov_button(label, Vector2(4, y), Vector2(W - 8, 28), func(): _claim(q["id"], i))
				b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				y += 30.0
		else:
			say("quest_active")
	_ov_button("Zamknij", Vector2(4, 184), Vector2(W - 8, 18), _close_overlay)


func _goal_text(q: Dictionary) -> String:
	match q["type"]:
		"deliver":
			return "Oddaj: %s (ze skrytki lub ekwipunku)" % ItemDB.get_def(q["item"]).get("name", q["item"])
		"kill":
			return "Zabij: %s" % ("oficera dowodzącego" if q["faction"] == "Elita" else q["faction"])
		"extract":
			return "Ewakuuj się z: %s" % Biomes.get_def(q["biome"]).get("name", q["biome"])
	return ""


func _ov_button(text: String, pos: Vector2, sz: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.add_theme_font_size_override("font_size", 8)
	b.pressed.connect(cb)
	_overlay.add_child(b)
	return b


func _claim(id: String, choice: int) -> void:
	var res := Game.complete_quest(id, choice)
	if res == "NO_ROOM":
		Audio.play("ui_deny")
		ui._flash("Skrytka za mała na nagrodę. Zrób miejsce i spróbuj ponownie.")
		return
	if res == "":
		return
	Audio.play("quest_done", -2.0)
	ui._flash("Zadanie ukończone. Nagroda: %s" % res)
	_close_overlay()
	say("quest_done")
	ui.refresh()
	refresh()
