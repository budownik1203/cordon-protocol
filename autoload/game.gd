extends Node
## Stan gry między rajdami: skrytka, pieniądze, wyposażenie, zapis, raport z rajdu.

const SAVE_PATH := "user://save.json"
const STASH_COLS := 10
const STASH_ROWS := 14

var stash: Bag = Bag.grid(STASH_COLS, STASH_ROWS)
var equipment := Equipment.new()
var money: int = 0
var raids_done: int = 0
var deaths: int = 0
var extractions: int = 0
var pending_report: Dictionary = {}


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
	pending_report = {}
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


func save_game() -> void:
	var d := {
		"money": money, "raids": raids_done, "deaths": deaths, "ext": extractions,
		"stash": stash.to_array(), "equipment": equipment.to_dict(),
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
	stash = Bag.grid(STASH_COLS, STASH_ROWS)
	stash.from_array(d.get("stash", []))
	equipment = Equipment.new()
	equipment.from_dict(d.get("equipment", {}))
	return true
