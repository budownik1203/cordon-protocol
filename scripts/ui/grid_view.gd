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
var _hover_cell := Vector2i(-1, -1)


func set_bag(b: Bag) -> void:
	bag = b
	custom_minimum_size = Vector2(b.w * CELL, b.h * CELL)
	size = custom_minimum_size
	queue_redraw()


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
		draw_string(font, r.position + Vector2(2, 8), label.substr(0, max_chars), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 1, 1))
		if it.count > 1:
			draw_string(font, r.position + Vector2(2, r.size.y - 2), "x%d" % it.count, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 0.95, 0.6))
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
