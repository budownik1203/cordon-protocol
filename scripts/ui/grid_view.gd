class_name GridView
extends Control
## Widok siatki pojemnika: rysuje komórki i przedmioty, zgłasza kliknięcia i najechania.

signal cell_input(view: GridView, cell: Vector2i, event: InputEventMouseButton)
signal hovered(view: GridView, item: Item)

const CELL := 16

var bag: Bag
var hide_unrevealed: bool = false
var title: String = ""
var held_ref: Callable  # zwraca aktualnie trzymany Item (do podświetlenia możliwości położenia)
var hidden_ref: Dictionary = {}  # przedmioty chwilowo niewidoczne (leci do nich animowany duch)
var flash: Dictionary = {}  # Item -> pozostały czas błysku (np. po dołożeniu naboju)
var _hover_cell := Vector2i(-1, -1)


func set_bag(b: Bag) -> void:
	bag = b
	custom_minimum_size = Vector2(b.w * CELL, b.h * CELL)
	size = custom_minimum_size
	queue_redraw()


func flash_item(it: Item, t: float = 0.25) -> void:
	flash[it] = t
	set_process(true)


func _process(delta: float) -> void:
	for k in flash.keys():
		flash[k] -= delta
		if flash[k] <= 0.0:
			flash.erase(k)
	if flash.is_empty():
		set_process(false)
	queue_redraw()


func item_rect(it: Item) -> Rect2:
	return Rect2(it.x * CELL + 1, it.y * CELL + 1, it.width() * CELL - 2, it.height() * CELL - 2)


func to_cell(local: Vector2) -> Vector2i:
	return Vector2i(int(floor(local.x / CELL)), int(floor(local.y / CELL)))


func _gui_input(event: InputEvent) -> void:
	if bag == null:
		return
	if event is InputEventMouseMotion:
		var c := to_cell(event.position)
		if c != _hover_cell:
			_hover_cell = c
			hovered.emit(self, bag.item_at(c.x, c.y))
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		cell_input.emit(self, to_cell(event.position), event)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover_cell = Vector2i(-1, -1)
		hovered.emit(self, null)
		queue_redraw()


func _draw() -> void:
	if bag == null:
		return
	for y in bag.h:
		for x in bag.w:
			if bag.mask[y][x]:
				var r := Rect2(x * CELL, y * CELL, CELL, CELL)
				draw_rect(r, Color(0.16, 0.17, 0.19))
				draw_rect(r, Color(0.3, 0.32, 0.36), false, 1.0)
	var font := ThemeDB.fallback_font
	for it: Item in bag.items:
		if hidden_ref.has(it):
			continue
		var r := Rect2(it.x * CELL + 1, it.y * CELL + 1, it.width() * CELL - 2, it.height() * CELL - 2)
		if hide_unrevealed and not it.revealed:
			draw_rect(r, Color(0.25, 0.25, 0.28))
			draw_string(font, r.position + Vector2(r.size.x / 2.0 - 3, r.size.y / 2.0 + 4), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.8, 0.8, 0.8))
			continue
		var c: Color = it.color()
		draw_rect(r, c.darkened(0.25))
		draw_rect(r, c.lightened(0.2), false, 1.0)
		var label: String = it.item_name()
		var max_chars := maxi(2, int(r.size.x / 4.5))
		if not it.is_mag():
			draw_string(font, r.position + Vector2(2, 8), label.substr(0, max_chars), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 1, 1))
		if it.count > 1:
			draw_string(font, r.position + Vector2(2, r.size.y - 2), "x%d" % it.count, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 0.95, 0.6))
		if it.is_mag():
			_draw_mag_fill(it, r, font)
		elif it.mag != null:
			draw_string(font, r.position + Vector2(2, r.size.y - 2), "%d/%d" % [it.mag.loaded, it.mag.mag_cap()],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0.7, 1.0, 0.7))
		if it.insured:
			draw_rect(Rect2(r.position.x + r.size.x - 6, r.position.y, 6, 7), Color(0.2, 0.55, 0.9))
			draw_string(font, r.position + Vector2(r.size.x - 5, 6), "U", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(1, 1, 1))
		if flash.has(it):
			draw_rect(r, Color(1, 1, 0.7, clampf(flash[it] / 0.25, 0.0, 1.0) * 0.55))
	# podświetlenie miejsca docelowego
	if _hover_cell.x >= 0 and held_ref.is_valid():
		var h: Item = held_ref.call()
		if h != null:
			var tl := _held_top_left(h)
			var ok := bag.fits(h, tl.x, tl.y)
			var r2 := Rect2(tl.x * CELL, tl.y * CELL, h.width() * CELL, h.height() * CELL)
			draw_rect(r2, Color(0.2, 0.9, 0.3, 0.25) if ok else Color(0.9, 0.2, 0.2, 0.25))


func _held_top_left(h: Item) -> Vector2i:
	return _hover_cell - Vector2i(h.width() / 2, h.height() / 2)


func held_top_left(h: Item, cell: Vector2i) -> Vector2i:
	return cell - Vector2i(h.width() / 2, h.height() / 2)


## Magazynek: liczba nabojów i pasek wypełnienia wzdłuż dłuższego boku.
func _draw_mag_fill(it: Item, r: Rect2, font: Font) -> void:
	var cap := maxf(1.0, float(it.mag_cap()))
	var frac := clampf(it.loaded / cap, 0.0, 1.0)
	var col := Color(0.95, 0.8, 0.25) if frac > 0.0 else Color(0.45, 0.45, 0.45)
	var vertical := r.size.y >= r.size.x
	var bar: Rect2
	if vertical:
		bar = Rect2(r.position.x + r.size.x - 4, r.position.y + 2, 3, r.size.y - 4)
	else:
		bar = Rect2(r.position.x + 2, r.end.y - 4, r.size.x - 4, 3)
	draw_rect(bar, Color(0.05, 0.05, 0.06))
	if vertical:
		var fh := bar.size.y * frac
		draw_rect(Rect2(bar.position.x, bar.end.y - fh, bar.size.x, fh), col)
	else:
		draw_rect(Rect2(bar.position.x, bar.position.y, bar.size.x * frac, bar.size.y), col)
	draw_string(font, r.position + Vector2(2, 8), str(it.loaded), HORIZONTAL_ALIGNMENT_LEFT, -1, 7,
		Color(1, 0.95, 0.6) if it.loaded > 0 else Color(0.65, 0.65, 0.65))
	if r.size.y >= 26:
		draw_string(font, r.position + Vector2(2, 17), "mag", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0.8, 0.85, 0.75))
