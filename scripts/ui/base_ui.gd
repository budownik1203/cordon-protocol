extends Node
## Baza: skrytka, ekwipunek, handlarz, wyjście na rajd i raport po rajdzie.

var inv: InventoryUI
var _top: CanvasLayer
var _status: Label
var _report_layer: CanvasLayer


func _ready() -> void:
	inv = InventoryUI.new()
	inv.layer = 1
	add_child(inv)
	inv.setup(Game.equipment, null, false)

	_top = CanvasLayer.new()
	_top.layer = 20
	add_child(_top)
	var bar := Control.new()
	bar.position = Vector2(124, 332)
	_top.add_child(bar)
	_status = Label.new()
	_status.position = Vector2(0, -10)
	_status.add_theme_font_size_override("font_size", 8)
	bar.add_child(_status)
	_button(bar, "NA RAJD", Vector2(0, 2), Vector2(60, 22), _start_raid)
	_button(bar, "Zestaw startowy", Vector2(66, 2), Vector2(84, 22), _starter)
	_button(bar, "Zapisz", Vector2(156, 2), Vector2(46, 22), func(): Game.save_game(); _say("Zapisano."))
	_button(bar, "Nowa gra", Vector2(208, 2), Vector2(56, 22), _new_game)
	_update_status()
	if not Game.pending_report.is_empty():
		_show_report(Game.pending_report)
		Game.pending_report = {}


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


func _say(m: String) -> void:
	inv._flash(m)


func _starter() -> void:
	Game.give_starter_kit()
	inv.refresh()
	_say("Wydano zestaw startowy (pistolet, amunicja, bandaże).")


func _new_game() -> void:
	Game.new_game()
	get_tree().reload_current_scene()


func _start_raid() -> void:
	if Game.equipment.get_slot("primary") == null and Game.equipment.get_slot("pistol") == null:
		_say("Idziesz bez broni? Załóż broń albo weź zestaw startowy.")
		return
	inv._return_held()
	Game.save_game()
	get_tree().change_scene_to_file("res://scenes/raid.tscn")


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
	if k.get("Fauna", 0) >= 1:
		notes.append("Zlikwidowano faunę (%d szt.). Dopisek: zwierzęta były już w stanie wskazującym." % k["Fauna"])
	return notes


func _show_report(r: Dictionary) -> void:
	_report_layer = CanvasLayer.new()
	_report_layer.layer = 50
	add_child(_report_layer)
	var bg := ColorRect.new()
	bg.size = Vector2(640, 360)
	bg.color = Color(0.03, 0.04, 0.05, 0.97)
	_report_layer.add_child(bg)
	var t: float = r.get("time", 0.0)
	var lines := []
	lines.append("RAPORT Z RAJDU nr %04d" % (Game.raids_done))
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
	lines.append("")
	lines.append("Przeszukane kontenery: %d   Poziom zagrożenia: %d" % [r.get("boxes", 0), r.get("threat", 0)])
	var delta_val: int = r["end_value"] - r["start_value"]
	lines.append("Wartość wyposażenia: %d -> %d (%s%d)" % [r["start_value"], r["end_value"], "+" if delta_val >= 0 else "", delta_val])
	if r["result"] == "dead":
		lines.append("Wyposażenie poza bezpiecznym kontenerem uznano za utracone.")
		lines.append("Zestaw startowy jest dostępny bezpłatnie.")
	var l := Label.new()
	l.text = "\n".join(lines)
	l.position = Vector2(40, 30)
	l.size = Vector2(560, 260)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 10)
	_report_layer.add_child(l)
	var b := Button.new()
	b.text = "Wróć do bazy"
	b.position = Vector2(260, 310)
	b.size = Vector2(120, 26)
	b.pressed.connect(func(): _report_layer.queue_free())
	_report_layer.add_child(b)
