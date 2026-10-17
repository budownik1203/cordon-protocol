class_name Equipment
extends RefCounted
## Wyposażenie operatora: sloty na ciele i pojemniki. Kieszenie są zawsze dostępne.

const SLOTS := ["head", "armor", "rig", "backpack", "belt", "primary", "pistol", "secure"]
const SLOT_NAMES := {
	"head": "Hełm", "armor": "Pancerz", "rig": "Kamizelka", "backpack": "Plecak",
	"belt": "Pas", "primary": "Broń główna", "pistol": "Pistolet", "secure": "Bezp. kontener",
}

var slots: Dictionary = {}  # slot -> Item
var pockets := Bag.new(["XXXX"], 0.0)

## Progi obciążenia (kg): lekki, obciążony, przeciążony, krytyczny.
const LOAD_LIMITS := [14.0, 22.0, 30.0]
const LOAD_NAMES := ["lekki", "obciążony", "przeciążony", "krytyczny"]
const LOAD_SPEED := [1.0, 0.88, 0.7, 0.45]


func _init() -> void:
	for s in SLOTS:
		slots[s] = null


func get_slot(s: String) -> Item:
	return slots.get(s)


func accepts(slot: String, it: Item) -> bool:
	return it != null and it.def().get("slot", "") == slot


## Zakłada przedmiot w slot; zwraca poprzedni (lub null). Nie sprawdza typu.
func equip(slot: String, it: Item) -> Item:
	var prev: Item = slots[slot]
	slots[slot] = it
	return prev


func unequip(slot: String) -> Item:
	var prev: Item = slots[slot]
	slots[slot] = null
	return prev


## Pojemniki do wyświetlenia: [{name, bag, quick}]
func bags() -> Array:
	var out := [{"name": "Kieszenie", "bag": pockets, "quick": true, "slot": ""}]
	for s in ["rig", "belt", "backpack", "secure"]:
		var it: Item = slots[s]
		if it and it.bag:
			out.append({"name": it.item_name(), "bag": it.bag, "quick": s != "backpack", "slot": s})
	return out


## Wkłada przedmiot do pierwszego pasującego pojemnika. quick_first: kieszenie, kamizelka i pas.
func add_auto(it: Item, quick_first: bool = false) -> bool:
	var order := bags()
	if quick_first:
		order.sort_custom(func(a, b): return a["quick"] and not b["quick"])
	for e in order:
		if e["slot"] == "secure":
			continue
		if e["bag"].add_auto(it):
			return true
	return false


func gear_weight() -> float:
	var s := 0.0
	for slot in SLOTS:
		var it: Item = slots[slot]
		if it:
			s += it.def().get("weight", 0.0)
			if it.mag:
				s += it.mag.total_weight()
	return s


## Całkowita waga: sprzęt na ciele plus zawartość pojemników po redukcji.
func total_weight() -> float:
	var s := gear_weight() + pockets.effective_weight()
	for slot in SLOTS:
		var it: Item = slots[slot]
		if it and it.bag:
			s += it.bag.effective_weight()
	return s


func load_level() -> int:
	var w := total_weight()
	for i in LOAD_LIMITS.size():
		if w < LOAD_LIMITS[i]:
			return i
	return 3


func speed_mult() -> float:
	return LOAD_SPEED[load_level()]


func count_of(item_id: String) -> int:
	var n := pockets.count_of(item_id)
	for s in ["rig", "belt", "backpack"]:
		var it: Item = slots[s]
		if it and it.bag:
			n += it.bag.count_of(item_id)
	return n


## Zabiera przedmioty: kieszenie, kamizelka, pas, na końcu plecak.
## Zwraca [ile zabrano, czy_z_plecaka].
func take(item_id: String, n: int) -> Array:
	var taken := 0
	var from_backpack := false
	for e in bags():
		if e["slot"] == "secure":
			continue
		if taken >= n:
			break
		var t: int = e["bag"].take(item_id, n - taken)
		if t > 0 and e["slot"] == "backpack":
			from_backpack = true
		taken += t
	return [taken, from_backpack]


## Zapasowe magazynki danego typu w pojemnikach (bez bezpiecznego): [{item, bag, quick, slot}].
func find_mags(mag_id: String) -> Array:
	var out := []
	for e in bags():
		if e["slot"] == "secure":
			continue
		for it: Item in e["bag"].items:
			if it.id == mag_id:
				out.append({"item": it, "bag": e["bag"], "quick": e["quick"], "slot": e["slot"]})
	return out


## Przekłada jeden nabój z luźnej amunicji do pierwszego niepełnego magazynka
## (poza włożonymi do broni). Zwraca ten magazynek albo null.
func load_step() -> Item:
	for e in bags():
		if e["slot"] == "secure":
			continue
		for it: Item in e["bag"].items:
			if it.is_mag() and it.loaded < it.mag_cap():
				if take(it.ammo_item_id(), 1)[0] > 0:
					it.loaded += 1
					return it
	return null


## Natychmiast napełnia wszystkie magazynki i wkłada magazynek do pustej broni.
func prepare_all() -> void:
	while load_step() != null:
		pass
	for s in ["primary", "pistol"]:
		var w: Item = slots[s]
		if w == null or w.mag != null:
			continue
		var best := {}
		for c in find_mags(w.def().get("mag_id", "")):
			if best.is_empty() or c["item"].loaded > best["item"].loaded:
				best = c
		if not best.is_empty():
			best["bag"].remove(best["item"])
			w.mag = best["item"]


## Wszystko poza bezpiecznym kontenerem przepada (śmierć).
func lose_all_but_secure() -> void:
	for s in SLOTS:
		if s != "secure":
			slots[s] = null
	pockets = Bag.new(["XXXX"], 0.0)


func total_value() -> int:
	var v := 0
	for s in SLOTS:
		var it: Item = slots[s]
		if it:
			v += it.total_value()
	v += _bag_value(pockets)
	return v


func _bag_value(b: Bag) -> int:
	var v := 0
	for it in b.items:
		v += it.total_value()
	return v


func to_dict() -> Dictionary:
	var d := {"pockets": pockets.to_array(), "slots": {}}
	for s in SLOTS:
		if slots[s]:
			d["slots"][s] = slots[s].to_dict()
	return d


func from_dict(d: Dictionary) -> void:
	for s in SLOTS:
		slots[s] = null
	pockets = Bag.new(["XXXX"], 0.0)
	pockets.from_array(d.get("pockets", []))
	for s in d.get("slots", {}):
		slots[s] = Item.from_dict(d["slots"][s])
