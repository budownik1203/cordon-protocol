extends Node
## Baza: skrytka, ekwipunek, handlarze, wybór terenu, kontrakt/szkolenie i raport po rajdzie.

var inv: InventoryUI
var _top: CanvasLayer
var _status: Label
var _report_layer: CanvasLayer
var _contract_layer: CanvasLayer
var _biome_btn: Button
var _raid_btn: Button
var _skip_btn: Button


func _ready() -> void:
	inv = InventoryUI.new()
	inv.layer = 1
	add_child(inv)
	inv.setup(Game.equipment, null, false)

	_top = CanvasLayer.new()
	_top.layer = 20
	add_child(_top)
	var bar := Control.new()
	bar.position = Vector2(124, 338)
	_top.add_child(bar)
	_status = Label.new()
	_status.position = Vector2(0, -10)
	_status.add_theme_font_size_override("font_size", 8)
	bar.add_child(_status)
	_raid_btn = _button(bar, "NA RAJD", Vector2(0, 0), Vector2(70, 22), _start_raid)
	_biome_btn = _button(bar, "", Vector2(76, 0), Vector2(160, 22), _cycle_biome)
	_button(bar, "Zestaw startowy", Vector2(242, 0), Vector2(84, 22), _starter)
	_button(bar, "Zapisz", Vector2(332, 0), Vector2(44, 22), func(): Game.save_game(); _say("Zapisano."))
	_button(bar, "Nowa gra", Vector2(382, 0), Vector2(56, 22), _new_game)
	_button(bar, "Test 3D (z góry)", Vector2(-120, 0), Vector2(114, 11), func(): get_tree().change_scene_to_file("res://scenes/proto3d.tscn"))
	_button(bar, "Test FPS", Vector2(-120, 11), Vector2(114, 11), func(): get_tree().change_scene_to_file("res://scenes/protofps.tscn"))
	_skip_btn = _button(bar, "Pomiń szkolenie", Vector2(444, 0), Vector2(80, 22), _skip_tutorial)
	_update_buttons()
	_update_status()
	Audio.ambient("amb_base", -15.0)

	var got := Game.collect_mail()
	if not got.is_empty():
		Game.save_game()
		inv.refresh()
		if inv.trader_panel:
			inv.trader_panel.say("mail_ok")
		_say("Poczta od ubezpieczyciela: %s." % ", ".join(got), 6.0)
		Audio.play("key_found", -4.0)
	elif not Game.mail.is_empty() and inv.trader_panel and randf() < 0.4:
		pass

	if not Game.pending_report.is_empty():
		_show_report(Game.pending_report)
		Game.pending_report = {}
		if inv.trader_panel:
			inv.trader_panel.select(inv.trader_panel.trader, true)
	elif not Game.contract_seen:
		_show_contract()


func _button(parent: Control, text: String, pos: Vector2, sz: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.add_theme_font_size_override("font_size", 8)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _process(_delta: float) -> void:
	_update_status()


func _update_status() -> void:
	_status.text = "Bony: %d   Rajdy: %d   Ewakuacje: %d   Zgony: %d" % [
		Game.money, Game.raids_done, Game.extractions, Game.deaths]
	if not Game.corpse.is_empty():
		_status.text += "   Ciało czeka w: %s" % Biomes.get_def(Game.corpse.get("biome", "")).get("short", "?")


func _update_buttons() -> void:
	_raid_btn.text = "NA RAJD" if Game.tutorial_done else "SZKOLENIE"
	_biome_btn.text = "Teren: %s" % Biomes.get_def(Game.selected_biome)["name"]
	_biome_btn.disabled = not Game.tutorial_done
	_skip_btn.visible = not Game.tutorial_done


func _say(m: String, secs: float = 3.5) -> void:
	inv._flash(m)


func _cycle_biome() -> void:
	var order: Array = Biomes.ORDER
	var i: int = order.find(Game.selected_biome)
	for step in order.size():
		i = (i + 1) % order.size()
		if Game.is_unlocked(order[i]):
			break
	Game.selected_biome = order[i]
	Audio.play("ui_click")
	_update_buttons()
	var d := Biomes.get_def(Game.selected_biome)
	var extra := ""
	if Game.corpse.get("biome", "") == Game.selected_biome:
		extra = " Twoje ciało czeka w tym terenie."
	_say("%s%s" % [d["desc"], extra], 6.0)
	if not Game.is_unlocked("kompleks"):
		pass


func _starter() -> void:
	Game.give_starter_kit()
	inv.refresh()
	_say("Wydano zestaw startowy (pistolet, amunicja, bandaże).")


func _new_game() -> void:
	Game.new_game()
	get_tree().reload_current_scene()


func _skip_tutorial() -> void:
	Game.tutorial_done = true
	Game.contract_seen = true
	Game.last_ctx = "first"
	Game.save_game()
	_update_buttons()
	_say("Szkolenie pominięte.")


func _start_raid() -> void:
	if not Game.tutorial_done:
		Game.contract_seen = true
		Game.next_raid = {"tutorial": true, "biome": "szkolenie"}
		inv._return_held()
		Game.save_game()
		Audio.stop_all()
		get_tree().change_scene_to_file("res://scenes/raid.tscn")
		return
	if Game.equipment.get_slot("primary") == null and Game.equipment.get_slot("pistol") == null:
		_say("Idziesz bez broni? Załóż broń albo weź zestaw startowy.")
		Audio.play("ui_deny")
		return
	inv._return_held()
	Game.next_raid = {"biome": Game.selected_biome, "tutorial": false}
	Game.save_game()
	Audio.stop_all()
	get_tree().change_scene_to_file("res://scenes/raid.tscn")


# --- kontrakt na początek ----------------------------------------------------

## Łamie długie wiersze na słowach (Label w CanvasLayer nie zawsze zawija sam).
static func wrap_text(lines: Array, width_chars: int) -> String:
	var out := []
	for line in lines:
		var text: String = line
		if text.length() <= width_chars:
			out.append(text)
			continue
		var cur := ""
		for word in text.split(" "):
			if cur.length() + word.length() + 1 > width_chars and cur != "":
				out.append(cur)
				cur = word
			else:
				cur = word if cur == "" else cur + " " + word
		out.append(cur)
	return "\n".join(out)


func _show_contract() -> void:
	_contract_layer = CanvasLayer.new()
	_contract_layer.layer = 40
	add_child(_contract_layer)
	var bg := ColorRect.new()
	bg.size = Vector2(640, 360)
	bg.color = Color(0.03, 0.04, 0.05, 1.0)
	_contract_layer.add_child(bg)
	var l := Label.new()
	l.text = wrap_text(Dialogue.CONTRACT, 104)
	l.position = Vector2(50, 28)
	l.custom_minimum_size = Vector2(540, 250)
	l.size = Vector2(540, 250)
	l.add_theme_font_size_override("font_size", 10)
	_contract_layer.add_child(l)
	var b1 := Button.new()
	b1.text = "Podpisz i zacznij szkolenie"
	b1.position = Vector2(150, 300)
	b1.size = Vector2(200, 26)
	b1.pressed.connect(func():
		Game.contract_seen = true
		Game.save_game()
		Audio.play("ui_click")
		_contract_layer.queue_free()
		_start_raid())
	_contract_layer.add_child(b1)
	var b2 := Button.new()
	b2.text = "Podpisz, pomiń szkolenie"
	b2.position = Vector2(360, 300)
	b2.size = Vector2(150, 26)
	b2.pressed.connect(func():
		Audio.play("ui_click")
		_skip_tutorial()
		_contract_layer.queue_free())
	_contract_layer.add_child(b2)


# --- raport po rajdzie -----------------------------------------------------

func _death_note(r: Dictionary) -> String:
	var cause: String = r.get("cause", "")
	if r.get("last_source", "") == "fauna":
		return "Prosimy nie dokarmiać zwierząt Sobą."
	match cause:
		"Wykrwawienie":
			return "Komunikat: Prosimy o dostarczanie krwi w ilościach określonych w instrukcji."
		"Zniszczenie głowy":
			return "Ostrzeżenie: Głowa jest elementem krytycznym."
		"Zniszczenie klatki piersiowej":
			return "Uwaga: Klatka piersiowa nie jest elementem zapasowym."
	return "Przyczyna zgonu została odnotowana w aktach."


func _kill_notes(r: Dictionary) -> Array:
	var notes := []
	var k: Dictionary = r.get("kills", {})
	if k.get("Najemnicy", 0) >= 2:
		var loss := "bez strat własnych"
		if r.get("arms_hurt", false):
			loss = "ze stratami własnymi w postaci sprawności ręki"
		notes.append("Eliminacja oddziału Najemniczego (%d os.), %s." % [k["Najemnicy"], loss])
	if k.get("Szabrownicy", 0) >= 1:
		notes.append("Eliminacja grupy Szabrowników (%d os.). Dopisek: to dalej cywile." % k["Szabrownicy"])
	if k.get("Wojskowi", 0) >= 1:
		notes.append("Naruszono procedurę kordonu (%d os.). Sprawa zostanie rozpatrzona." % k["Wojskowi"])
	if k.get("Elita", 0) >= 1:
		notes.append("Eliminacja oficera dowodzącego. Pismo z gratulacjami wysłano pod adres, którego nie ma.")
	if k.get("Fauna", 0) >= 1:
		notes.append("Zlikwidowano faunę (%d szt.). Dopisek: zwierzęta były już w stanie wskazującym." % k["Fauna"])
	return notes


func _report_lines(r: Dictionary) -> Array:
	var lines := []
	var t: float = r.get("time", 0.0)
	if r["result"] == "tutorial_ok":
		return ["RAPORT ZE SZKOLENIA", "Czas: %02d:%02d" % [int(t) / 60, int(t) % 60], "",
			"Wynik: ZALICZONE. Zaświadczenie zostanie wydane po wystawieniu zaświadczenia o zaświadczeniu.", "",
			"Szkolenie nie liczy się do wyniku i niczego nie zabrało ani nie dało.",
			"Odblokowano: wybór terenu, rajdy właściwe. Handlarze czekają.",
			"Wskazówka: ciało po śmierci zostaje w terenie, a ubezpieczenie zwraca sprzęt pocztą (zazwyczaj)."]
	if r["result"] == "tutorial_fail":
		return ["RAPORT ZE SZKOLENIA", "Czas: %02d:%02d" % [int(t) / 60, int(t) % 60], "",
			"Wynik: NIEZALICZONE. Przyczyna: %s." % r.get("cause", "nieustalona"), _death_note(r), "",
			"Szkolenie można powtórzyć. Nic nie przepadło."]
	lines.append("RAPORT Z RAJDU nr %04d — %s" % [Game.raids_done, Biomes.get_def(r.get("biome", "przedmiescia"))["name"]])
	lines.append("Czas operacji: %02d:%02d" % [int(t) / 60, int(t) % 60])
	if r["result"] == "extracted":
		lines.append("Wynik: OPERATOR WRÓCIŁ. Formalności zostały dopełnione.")
	else:
		lines.append("Wynik: OPERATOR NIE WRÓCIŁ.")
		lines.append("Przyczyna: %s." % r.get("cause", "nieustalona"))
		lines.append(_death_note(r))
	lines.append("")
	var notes := _kill_notes(r)
	if notes.is_empty():
		lines.append("Eliminacje: brak. (Odnotowano z uznaniem.)")
	for n in notes:
		lines.append(n)
	if r.get("anomaly", false):
		lines.append("Odnotowano pobyt w pomieszczeniu, które się powtarza. Prosimy do niego nie wracać. Pomieszczenie prosi o to samo.")
	lines.append("")
	lines.append("Przeszukane kontenery: %d   Poziom zagrożenia: %d" % [r.get("boxes", 0), r.get("threat", 0)])
	var delta_val: int = r["end_value"] - r["start_value"]
	lines.append("Wartość wyposażenia: %d -> %d (%s%d)" % [r["start_value"], r["end_value"], "+" if delta_val >= 0 else "", delta_val])
	if r.get("corpse_found", false):
		lines.append("Odzyskano z własnych zwłok: %d przedmiotów." % r.get("corpse_taken", 0))
	if r["result"] == "dead":
		lines.append("Wyposażenie poza bezpiecznym kontenerem uznano za utracone.")
		if r.get("corpse_items", 0) > 0:
			lines.append("Zwłoki operatora (%d przedmiotów) pozostają w terenie. Odbiór własny. Zaleca się towarzystwo." % r["corpse_items"])
		if r.get("had_old_corpse", false):
			lines.append("Poprzednie zwłoki zostały uprzątnięte wraz z zawartością.")
		var back: Array = r.get("insured_back", [])
		var gone: Array = r.get("insured_lost", [])
		if not back.is_empty():
			lines.append("Ubezpieczyciel zwróci po kolejnym rajdzie: %s." % ", ".join(back))
		if not gone.is_empty():
			lines.append("Ubezpieczyciel informuje, że (%s) uległo rozproszeniu. Rozproszenie nie podlega reklamacji." % ", ".join(gone))
		lines.append("Zestaw startowy jest dostępny bezpłatnie.")
	if r.get("unlocked", "") != "":
		lines.append("")
		lines.append("ODBLOKOWANO NOWY TEREN: %s. Wybierz go przyciskiem obok „NA RAJD”." % Biomes.get_def(r["unlocked"])["name"])
	return lines


func _show_report(r: Dictionary) -> void:
	_report_layer = CanvasLayer.new()
	_report_layer.layer = 50
	add_child(_report_layer)
	var bg := ColorRect.new()
	bg.size = Vector2(640, 360)
	bg.color = Color(0.03, 0.04, 0.05, 1.0)
	_report_layer.add_child(bg)
	var l := Label.new()
	l.text = wrap_text(_report_lines(r), 118)
	l.position = Vector2(30, 10)
	l.custom_minimum_size = Vector2(560, 270)
	l.size = Vector2(580, 296)
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_constant_override("line_spacing", -2)
	_report_layer.add_child(l)
	var b := Button.new()
	b.text = "Wróć do bazy"
	b.position = Vector2(260, 316)
	b.size = Vector2(120, 26)
	b.pressed.connect(func():
		Audio.play("ui_click")
		_report_layer.queue_free()
		_update_buttons())
	_report_layer.add_child(b)
	_update_buttons()
