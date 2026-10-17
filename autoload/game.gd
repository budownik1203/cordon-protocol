extends Node
## Stan gry między rajdami: skrytka, pieniądze, wyposażenie, zapis, raport z rajdu, ciało po śmierci,
## ubezpieczenie (poczta), zadania handlarzy, odblokowane biomy.

const SAVE_PATH := "user://save.json"
const STASH_COLS := 10
const STASH_ROWS := 14
const INSURE_RATE := 0.15
const INSURE_RETURN_CHANCE := 0.75
const CORPSE_PLUNDER_CHANCE := 0.2

var stash: Bag = Bag.grid(STASH_COLS, STASH_ROWS)
var equipment := Equipment.new()
var money: int = 0
var raids_done: int = 0
var deaths: int = 0
var extractions: int = 0
var death_streak: int = 0
var pending_report: Dictionary = {}
var last_report: Dictionary = {}  # kopia ostatniego raportu (zostaje po zamknięciu ekranu)
var next_raid: Dictionary = {}  # {"biome": id, "tutorial": bool}
var selected_biome: String = "przedmiescia"
var unlocked: Array = ["przedmiescia"]
var tutorial_done: bool = false
var contract_seen: bool = false
var corpse: Dictionary = {}  # {"biome", "items": [dict], "plundered": bool}
var mail: Array = []  # [{"item": dict, "ready": int}]
var quests: Dictionary = {}  # id -> {"state": "active"|"done", "base": {}, "choice": int}
var kills_total: Dictionary = {}
var extr_by_biome: Dictionary = {}
var last_ctx: String = ""  # kontekst dla dialogów po ostatnim rajdzie


func _ready() -> void:
	if not load_game():
		new_game()


func new_game() -> void:
	stash = Bag.grid(STASH_COLS, STASH_ROWS)
	equipment = Equipment.new()
	money = 2500
	raids_done = 0
	deaths = 0
	extractions = 0
	death_streak = 0
	pending_report = {}
	next_raid = {}
	selected_biome = "przedmiescia"
	unlocked = ["przedmiescia"]
	tutorial_done = false
	contract_seen = false
	corpse = {}
	mail = []
	quests = {}
	kills_total = {}
	extr_by_biome = {}
	last_ctx = "first"
	var starter := [
		["rifle_skm", 1], ["ammo_556", 90], ["ammo_9", 60], ["pistol_p9", 1], ["armor_3", 1],
		["helmet_2", 1], ["rig_a", 1], ["backpack_b", 1], ["belt_a", 1], ["secure_a", 1],
		["bandage", 4], ["hemostatic", 2], ["splint", 1], ["painkiller", 3],
	]
	for e in starter:
		stash.add_auto(Item.new(e[0], e[1]))
	save_game()


## Darmowy tani zestaw: gwarantuje, że po serii porażek da się wyjść na rajd.
func give_starter_kit() -> void:
	var eq := equipment
	if eq.get_slot("pistol") == null:
		var p := Item.new("pistol_p9")
		p.loaded = 12
		eq.equip("pistol", p)
	if eq.get_slot("belt") == null:
		eq.equip("belt", Item.new("belt_a"))
	if eq.get_slot("secure") == null:
		eq.equip("secure", Item.new("secure_a"))
	eq.add_auto(Item.new("ammo_9", 30), true)
	eq.add_auto(Item.new("bandage", 2), true)


# --- przedmioty w skrytce i ekwipunku (zadania) ---------------------------------

func count_item(id: String) -> int:
	return stash.count_of(id) + equipment.count_of(id)


func take_item(id: String, n: int) -> int:
	var got := stash.take(id, n)
	if got < n:
		got += equipment.take(id, n - got)[0]
	return got


# --- śmierć: ciało, ubezpieczenie ----------------------------------------------------

## Zdejmuje cały sprzęt poza bezpiecznym kontenerem. Ubezpieczone przedmioty wracają pocztą (z ryzykiem),
## reszta zostaje przy ciele w biomie. Zwraca opis do raportu.
func process_death(eq: Equipment, biome: String) -> Dictionary:
	var lost: Array = []
	for s in Equipment.SLOTS:
		if s == "secure":
			continue
		var it: Item = eq.get_slot(s)
		if it:
			lost.append(it)
			eq.slots[s] = null
	for it in eq.pockets.items:
		lost.append(it)
	eq.pockets = Bag.new(["XXXX"], 0.0)
	var corpse_items: Array = []
	var back: Array = []
	var gone: Array = []
	for it in lost:
		if it.insured:
			if it.bag:
				for inner in it.bag.items:
					corpse_items.append(inner)
				it.bag.items.clear()
			it.insured = false
			if randf() < INSURE_RETURN_CHANCE:
				mail.append({"item": it.to_dict(), "ready": raids_done + 1})
				back.append(it.item_name())
			else:
				gone.append(it.item_name())
		else:
			corpse_items.append(it)
	var had_old := not corpse.is_empty()
	corpse = {}
	if not corpse_items.is_empty():
		corpse = {"biome": biome, "items": corpse_items.map(func(i): return i.to_dict()), "plundered": false}
	return {"insured_back": back, "insured_lost": gone, "corpse_items": corpse_items.size(), "had_old_corpse": had_old}


## Przedmioty z poczty gotowe do odbioru (po kolejnym rajdzie). Zwraca nazwy odebranych.
func collect_mail() -> Array:
	var got: Array = []
	var keep: Array = []
	for m in mail:
		if raids_done >= int(m["ready"]):
			var it := Item.from_dict(m["item"])
			if stash.add_auto(it):
				got.append(it.item_name())
			else:
				keep.append(m)
		else:
			keep.append(m)
	mail = keep
	return got


func mail_waiting() -> int:
	return mail.size()


## Stan ciała do rozmieszczenia w kolejnym rajdzie danego biomu: zwraca listę Item (po ewentualnym ogołoceniu).
func take_corpse_items(biome: String) -> Array:
	if corpse.is_empty() or corpse.get("biome", "") != biome:
		return []
	var out: Array = []
	for d in corpse["items"]:
		var it := Item.from_dict(d)
		if not corpse.get("plundered", false) and randf() < CORPSE_PLUNDER_CHANCE:
			continue
		out.append(it)
	corpse["plundered"] = true
	return out


## Po rajdzie: to, co zostało w ciele, zostaje w zapisie (lub ciało znika, jeśli puste).
func store_corpse_remaining(biome: String, remaining: Array) -> void:
	if remaining.is_empty():
		corpse = {}
		return
	corpse = {"biome": biome, "items": remaining.map(func(i): return i.to_dict()), "plundered": true}


# --- biomy ------------------------------------------------------------------------

func is_unlocked(biome: String) -> bool:
	return biome in unlocked


func unlock(biome: String) -> bool:
	if biome in unlocked:
		return false
	unlocked.append(biome)
	return true


## Podsumowanie rajdu: statystyki, odblokowania, kontekst dialogów handlarzy.
func register_raid(report: Dictionary, biome: String) -> Dictionary:
	var info := {"unlocked": ""}
	var k: Dictionary = report.get("kills", {})
	for f in k:
		kills_total[f] = int(kills_total.get(f, 0)) + int(k[f])
	var ctx := "greet"
	if report["result"] == "dead":
		death_streak += 1
		ctx = "many_deaths" if death_streak >= 3 else "after_death"
	else:
		death_streak = 0
		extr_by_biome[biome] = int(extr_by_biome.get(biome, 0)) + 1
		ctx = "after_extract"
		if report["end_value"] - report["start_value"] >= 1500:
			ctx = "profit"
		if biome == "przedmiescia" and unlock("kompleks"):
			info["unlocked"] = "kompleks"
	if int(k.get("Szabrownicy", 0)) >= 3:
		last_ctx = "kill_szab"
	else:
		last_ctx = ctx
	return info


# --- zadania ---------------------------------------------------------------------

func quest_state(id: String) -> String:
	return quests.get(id, {}).get("state", "")


## Pierwsze zadanie handlarza, które nie jest ukończone (łańcuch).
func current_quest(trader: String) -> Dictionary:
	for q in Quests.for_trader(trader):
		if quest_state(q["id"]) != "done":
			return q
	return {}


func previous_choice(trader: String) -> int:
	var last := -1
	for q in Quests.for_trader(trader):
		if quest_state(q["id"]) == "done":
			last = int(quests[q["id"]].get("choice", -1))
	return last


func accept_quest(id: String) -> void:
	var q := Quests.get_quest(id)
	if q.is_empty() or quest_state(id) != "":
		return
	var base := {}
	match q["type"]:
		"kill":
			base["kills"] = int(kills_total.get(q["faction"], 0))
		"extract":
			base["extr"] = int(extr_by_biome.get(q["biome"], 0))
	quests[id] = {"state": "active", "base": base, "choice": -1}


## [aktualnie, cel]
func quest_progress(id: String) -> Array:
	var q := Quests.get_quest(id)
	if q.is_empty() or not quests.has(id):
		return [0, 1]
	var base: Dictionary = quests[id].get("base", {})
	match q["type"]:
		"deliver":
			return [mini(count_item(q["item"]), q["n"]), q["n"]]
		"kill":
			return [mini(int(kills_total.get(q["faction"], 0)) - int(base.get("kills", 0)), q["n"]), q["n"]]
		"extract":
			return [mini(int(extr_by_biome.get(q["biome"], 0)) - int(base.get("extr", 0)), q["n"]), q["n"]]
	return [0, 1]


func quest_ready(id: String) -> bool:
	if quest_state(id) != "active":
		return false
	var p := quest_progress(id)
	return p[0] >= p[1]


## Zdaje zadanie i wypłaca nagrodę (index 0 lub 1). Zwraca opis lub "" gdy się nie udało.
func complete_quest(id: String, choice: int) -> String:
	if not quest_ready(id):
		return ""
	var q := Quests.get_quest(id)
	var reward: Dictionary = q["rewards"][choice]
	var items: Array = []
	for e in reward.get("items", []):
		var it := Item.new(e[0], e[1])
		items.append(it)
	# najpierw sprawdź, czy się zmieści (próbnie na kopii)
	var probe := Bag.from_dict_bag(stash)
	for it in items:
		if not probe.add_auto(Item.from_dict(it.to_dict())):
			return "NO_ROOM"
	if q["type"] == "deliver":
		take_item(q["item"], q["n"])
	for it in items:
		if it.type() == "weapon":
			it.loaded = 0
		stash.add_auto(it)
	money += int(reward.get("money", 0))
	quests[id]["state"] = "done"
	quests[id]["choice"] = choice
	return reward["label"]


# --- zapis -------------------------------------------------------------------------

func save_game() -> void:
	var d := {
		"money": money, "raids": raids_done, "deaths": deaths, "ext": extractions, "streak": death_streak,
		"stash": stash.to_array(), "equipment": equipment.to_dict(),
		"biome": selected_biome, "unlocked": unlocked, "tut": tutorial_done, "contract": contract_seen,
		"corpse": corpse, "mail": mail, "quests": quests, "kills": kills_total, "extr": extr_by_biome,
		"ctx": last_ctx,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))
		f.close()
		# kopia zapasowa poprzedniego zapisu
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH),
			ProjectSettings.globalize_path("user://save_backup.json"))


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = parsed
	money = int(d.get("money", 0))
	raids_done = int(d.get("raids", 0))
	deaths = int(d.get("deaths", 0))
	extractions = int(d.get("ext", 0))
	death_streak = int(d.get("streak", 0))
	stash = Bag.grid(STASH_COLS, STASH_ROWS)
	stash.from_array(d.get("stash", []))
	equipment = Equipment.new()
	equipment.from_dict(d.get("equipment", {}))
	selected_biome = d.get("biome", "przedmiescia")
	unlocked = d.get("unlocked", ["przedmiescia"])
	tutorial_done = d.get("tut", false)
	contract_seen = d.get("contract", false)
	corpse = d.get("corpse", {})
	mail = d.get("mail", [])
	quests = d.get("quests", {})
	kills_total = d.get("kills", {})
	extr_by_biome = d.get("extr", {})
	last_ctx = d.get("ctx", "")
	return true
