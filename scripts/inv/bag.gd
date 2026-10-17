class_name Bag
extends RefCounted
## Pojemnik z siatką (jak w Tarkovie): własny układ komórek i redukcja wagi.

var w: int
var h: int
var mask: Array = []  # mask[y][x] : bool
var reduction: float = 0.0
var items: Array = []  # Item


func _init(layout: Array, p_reduction: float = 0.0) -> void:
	h = layout.size()
	w = 0
	for row in layout:
		w = maxi(w, String(row).length())
	for y in h:
		var r := []
		var s: String = layout[y]
		for x in w:
			r.append(x < s.length() and s[x] == "X")
		mask.append(r)
	reduction = p_reduction


static func grid(cols: int, rows: int, p_reduction: float = 0.0) -> Bag:
	var layout := []
	for y in rows:
		layout.append("X".repeat(cols))
	return Bag.new(layout, p_reduction)


func cell_count() -> int:
	var n := 0
	for row in mask:
		for c in row:
			if c:
				n += 1
	return n


func fits(it: Item, cx: int, cy: int, ignore: Item = null) -> bool:
	var iw := it.width()
	var ih := it.height()
	if cx < 0 or cy < 0 or cx + iw > w or cy + ih > h:
		return false
	for yy in range(cy, cy + ih):
		for xx in range(cx, cx + iw):
			if not mask[yy][xx]:
				return false
	for other in items:
		if other == it or other == ignore:
			continue
		if cx < other.x + other.width() and cx + iw > other.x \
				and cy < other.y + other.height() and cy + ih > other.y:
			return false
	return true


func place(it: Item, cx: int, cy: int) -> bool:
	if not fits(it, cx, cy):
		return false
	it.x = cx
	it.y = cy
	if not items.has(it):
		items.append(it)
	return true


func remove(it: Item) -> void:
	items.erase(it)


func item_at(cx: int, cy: int) -> Item:
	for it in items:
		if cx >= it.x and cx < it.x + it.width() and cy >= it.y and cy < it.y + it.height():
			return it
	return null


## Znajduje wolne miejsce (próbuje obu obrotów). Zwraca true i umieszcza.
func add_auto(it: Item) -> bool:
	# najpierw dołóż do istniejących stosów
	if it.stack_max() > 1:
		for other: Item in items:
			if other.id == it.id and other.count < other.stack_max():
				var room: int = other.stack_max() - other.count
				var moved: int = mini(room, it.count)
				other.count += moved
				it.count -= moved
				if it.count <= 0:
					return true
	for rot in [false, true]:
		it.rotated = rot
		if rot and it.width() == it.height():
			continue
		for yy in h:
			for xx in w:
				if fits(it, xx, yy):
					it.x = xx
					it.y = yy
					items.append(it)
					return true
	it.rotated = false
	return false


func raw_weight() -> float:
	var s := 0.0
	for it in items:
		s += it.total_weight()
	return s


## Waga zawartości po redukcji pojemnika.
func effective_weight() -> float:
	return raw_weight() * (1.0 - reduction)


func count_of(item_id: String) -> int:
	var n := 0
	for it in items:
		if it.id == item_id:
			n += it.count
		if it.bag:
			n += it.bag.count_of(item_id)
	return n


## Zabiera do n sztuk przedmiotu o danym id; zwraca ile zabrano.
func take(item_id: String, n: int) -> int:
	var taken := 0
	for it in items.duplicate():
		if taken >= n:
			break
		if it.id == item_id:
			var t := mini(it.count, n - taken)
			it.count -= t
			taken += t
			if it.count <= 0:
				items.erase(it)
	return taken


func to_array() -> Array:
	var a := []
	for it in items:
		a.append(it.to_dict())
	return a


func from_array(a: Array) -> void:
	items.clear()
	for d in a:
		var it := Item.from_dict(d)
		items.append(it)
