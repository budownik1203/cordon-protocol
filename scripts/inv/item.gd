class_name Item
extends RefCounted
## Egzemplarz przedmiotu.

var id: String
var count: int = 1
var rotated: bool = false
var x: int = 0
var y: int = 0
var durability: float = -1.0
var loaded: int = 0  # naboje w magazynku (broń)
var text: String = ""  # treść dokumentu
var bag: Bag = null  # dla pojemników
var revealed: bool = true  # przeszukiwanie odsłania stopniowo
var insured: bool = false  # ubezpieczony: po śmierci wraca pocztą (z ryzykiem)


func _init(p_id: String = "", p_count: int = 1) -> void:
	id = p_id
	count = p_count
	var d := def()
	if d.is_empty():
		return
	if d.has("durability"):
		durability = d["durability"]
	if d.get("type", "") == "container":
		bag = Bag.new(d["layout"], d.get("reduction", 0.0))
	if d.get("type", "") == "doc":
		text = ItemDB.random_doc()


func def() -> Dictionary:
	return ItemDB.get_def(id)


func item_name() -> String:
	return def().get("name", id)


func type() -> String:
	return def().get("type", "")


func stack_max() -> int:
	return def().get("stack", 1)


func width() -> int:
	var w: int = def().get("w", 1)
	var h: int = def().get("h", 1)
	return h if rotated else w


func height() -> int:
	var w: int = def().get("w", 1)
	var h: int = def().get("h", 1)
	return w if rotated else h


func unit_value() -> int:
	return def().get("value", 0)


func total_value() -> int:
	var v := unit_value() * count
	if bag:
		for it in bag.items:
			v += it.total_value()
	return v


## Waga własna plus zawartość po redukcji wagi pojemnika.
func total_weight() -> float:
	var w: float = def().get("weight", 0.0) * count
	if bag:
		w += bag.effective_weight()
	return w


func color() -> Color:
	return def().get("color", Color(0.6, 0.6, 0.6))


func to_dict() -> Dictionary:
	var d := {"id": id, "n": count, "r": rotated, "x": x, "y": y, "d": durability, "l": loaded, "t": text, "i": insured}
	if bag:
		d["bag"] = bag.to_array()
	return d


static func from_dict(d: Dictionary) -> Item:
	var it := Item.new(d.get("id", ""), int(d.get("n", 1)))
	it.rotated = d.get("r", false)
	it.x = int(d.get("x", 0))
	it.y = int(d.get("y", 0))
	it.durability = float(d.get("d", -1.0))
	it.loaded = int(d.get("l", 0))
	it.text = d.get("t", it.text)
	it.insured = d.get("i", false)
	if it.bag and d.has("bag"):
		it.bag.from_array(d["bag"])
	return it
