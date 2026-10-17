class_name Item
extends RefCounted
## Egzemplarz przedmiotu.

var id: String
var count: int = 1
var rotated: bool = false
var x: int = 0
var y: int = 0
var durability: float = -1.0
var loaded: int = 0  # magazynek: liczba nabojów w środku
var mag: Item = null  # broń: włożony magazynek
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


func is_mag() -> bool:
	return def().get("type", "") == "mag"


func mag_cap() -> int:
	return def().get("cap", 0)


func ammo_item_id() -> String:
	return "ammo_" + String(def().get("ammo_type", ""))


## Naboje gotowe do strzału: w broni — z włożonego magazynka.
func rounds() -> int:
	if is_mag():
		return loaded
	return mag.loaded if mag else 0


## Nowa broń z włożonym magazynkiem (rounds < 0: pełny).
static func make_weapon(p_id: String, rounds: int = -1) -> Item:
	var w := Item.new(p_id)
	var mid: String = w.def().get("mag_id", "")
	if mid != "":
		var m := Item.new(mid)
		m.loaded = m.mag_cap() if rounds < 0 else mini(rounds, m.mag_cap())
		w.mag = m
	return w


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
	if is_mag():
		v += loaded * ItemDB.get_def(ammo_item_id()).get("value", 0)
	if mag:
		v += mag.total_value()
	if bag:
		for it in bag.items:
			v += it.total_value()
	return v


## Waga własna plus zawartość po redukcji wagi pojemnika.
func total_weight() -> float:
	var w: float = def().get("weight", 0.0) * count
	if is_mag():
		w += loaded * ItemDB.get_def(ammo_item_id()).get("weight", 0.0)
	if mag:
		w += mag.total_weight()
	if bag:
		w += bag.effective_weight()
	return w


func color() -> Color:
	return def().get("color", Color(0.6, 0.6, 0.6))


func to_dict() -> Dictionary:
	var d := {"id": id, "n": count, "r": rotated, "x": x, "y": y, "d": durability, "l": loaded, "t": text, "i": insured}
	if mag:
		d["mag"] = mag.to_dict()
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
	if d.has("mag"):
		it.mag = Item.from_dict(d["mag"])
	elif it.type() == "weapon" and it.loaded > 0 and it.def().get("mag_id", "") != "":
		# stary zapis: naboje w broni zamieniamy na magazynek
		it.mag = Item.new(it.def()["mag_id"])
		it.mag.loaded = mini(it.loaded, it.mag.mag_cap())
		it.loaded = 0
	if it.bag and d.has("bag"):
		it.bag.from_array(d["bag"])
	return it
