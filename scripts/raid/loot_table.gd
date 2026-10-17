class_name LootTable
extends RefCounted
## Tabele lootu: kontenery i ciała wrogów (waga = szansa względna).


static func _pick(rng: RandomNumberGenerator, table: Array) -> Array:
	var total := 0.0
	for e in table:
		total += e[0]
	var r := rng.randf() * total
	for e in table:
		r -= e[0]
		if r <= 0.0:
			return e
	return table[0]


static func _make(e: Array, rng: RandomNumberGenerator, biome: String = "przedmiescia") -> Item:
	var n := 1
	if e.size() > 3:
		n = rng.randi_range(e[2], e[3])
	var it := Item.new(e[1], n)
	if it.def().get("type", "") == "weapon":
		it.loaded = 0
	if it.durability > 0.0:
		it.durability *= rng.randf_range(0.5, 1.0)
	if it.id == "document":
		it.text = ItemDB.random_doc(biome)
	return it


const T_SZAFKA := [
	[20, "bandage", 1, 2], [10, "painkiller", 1, 1], [8, "hemostatic", 1, 1], [6, "splint", 1, 1],
	[16, "ammo_9", 8, 24], [14, "watch"], [12, "tape"], [10, "lamp"], [4, "battery"],
]
const T_SKRZYNIA := [
	[22, "ammo_556", 15, 45], [20, "ammo_9", 15, 40], [8, "armor_3"], [8, "helmet_2"], [4, "helmet_3"],
	[2, "armor_4"], [6, "rig_a"], [6, "rig_b"], [5, "belt_a"], [4, "backpack_a"], [4, "backpack_b"],
	[6, "pistol_p9"], [4, "smg_kr"], [3, "rifle_skm"], [10, "battery"], [7, "radio"],
]
const T_BIURKO := [
	[30, "document"], [14, "tape"], [12, "watch"], [8, "lamp"], [4, "key_exit"], [3, "sample"], [8, "radio"],
]
const T_SEJF := [
	[14, "sample"], [10, "key_exit"], [12, "watch", 1, 2], [8, "rifle_skm"], [8, "armor_4"], [8, "helmet_3"],
	[10, "ammo_556", 30, 60], [8, "hemostatic", 1, 2], [6, "radio"],
]
const T_SZAB := [
	[22, "ammo_9", 8, 25], [18, "bandage", 1, 1], [8, "painkiller"], [12, "watch"], [8, "tape"],
	[10, "pistol_p9"], [5, "lamp"], [4, "document"],
]
const T_NAJEM := [
	[22, "ammo_556", 15, 40], [10, "ammo_9", 10, 25], [18, "bandage", 1, 2], [12, "painkiller"],
	[8, "hemostatic"], [7, "armor_3"], [8, "helmet_2"], [5, "rifle_skm"], [4, "smg_kr"], [6, "radio"],
	[5, "sample"], [2, "ammo_762", 10, 20], [1, "dmr_sw"],
]
const T_WOJSK := [
	[22, "ammo_556", 20, 50], [14, "hemostatic", 1, 2], [12, "bandage", 1, 2], [8, "helmet_3"], [6, "armor_4"],
	[10, "rifle_skm"], [8, "key_exit"], [6, "radio"], [6, "battery"], [4, "document"], [4, "ammo_762", 10, 30], [2, "dmr_sw"], [2, "helmet_4"],
]
const T_KORP := [
	[24, "sample"], [20, "document"], [10, "tape"], [10, "ammo_9", 10, 20], [6, "key_exit"],
]


const T_LAB_SZAFA := [
	[18, "bandage", 1, 2], [14, "hemostatic", 1, 2], [12, "painkiller", 1, 2], [8, "splint"],
	[12, "sample"], [8, "datacard"], [10, "tape"], [6, "battery"], [8, "ammo_9", 10, 24],
]
const T_LAB_SKRZ := [
	[18, "ammo_556", 20, 50], [10, "ammo_762", 10, 24], [8, "armor_3"], [6, "armor_4"], [5, "helmet_3"],
	[2, "helmet_4"], [6, "rig_b"], [5, "backpack_a"], [4, "smg_kr"], [4, "rifle_skm"], [1, "dmr_sw"],
	[10, "battery"], [8, "radio"], [8, "datacard"],
]
const T_TERMINAL := [
	[38, "document"], [14, "datacard"], [12, "tape"], [10, "sample"], [6, "key_exit"], [8, "radio"], [6, "watch"],
]
const T_LAB_SEJF := [
	[16, "sample", 1, 2], [12, "datacard", 1, 2], [8, "key_exit"], [6, "armor_4"], [3, "armor_5"],
	[6, "helmet_3"], [3, "helmet_4"], [3, "dmr_sw"], [10, "ammo_762", 15, 30], [8, "hemostatic", 1, 2],
]
const T_ANOMALIA := [
	[30, "sample", 1, 2], [18, "datacard", 1, 2], [10, "key_exit"], [8, "armor_5"], [8, "helmet_4"],
	[8, "dmr_sw"], [10, "ammo_762", 20, 40],
]
const T_ELITA := [
	[16, "armor_5"], [14, "helmet_4"], [14, "dmr_sw"], [16, "ammo_762", 20, 40], [10, "hemostatic", 1, 2],
	[10, "sample"], [10, "datacard"], [10, "ammo_556", 30, 60],
]


static func roll(kind: String, rng: RandomNumberGenerator, biome: String = "przedmiescia") -> Array:
	var table: Array = T_SZAFKA
	var count := rng.randi_range(1, 3)
	if biome == "kompleks":
		match kind:
			"szafka":
				table = T_LAB_SZAFA
			"skrzynia":
				table = T_LAB_SKRZ
				count = rng.randi_range(2, 4)
			"biurko":
				table = T_TERMINAL
			"sejf":
				table = T_LAB_SEJF
				count = rng.randi_range(2, 3)
			"anomalia":
				table = T_ANOMALIA
				count = rng.randi_range(3, 4)
		if kind in ["szafka", "skrzynia", "biurko", "sejf", "anomalia"]:
			return _roll_table(table, count, rng, biome)
	match kind:
		"Elita":
			var out2 := [Item.new("key_exit")]
			for i in 3:
				out2.append(_make(_pick(rng, T_ELITA), rng, biome))
			return out2
		"skrzynia":
			table = T_SKRZYNIA
			count = rng.randi_range(2, 4)
		"biurko":
			table = T_BIURKO
			count = rng.randi_range(1, 3)
		"sejf":
			table = T_SEJF
			count = rng.randi_range(2, 3)
		"Szabrownicy":
			table = T_SZAB
			count = rng.randi_range(1, 3)
		"Najemnicy":
			table = T_NAJEM
			count = rng.randi_range(2, 4)
		"Wojskowi":
			table = T_WOJSK
			count = rng.randi_range(3, 4)
		"Korporacja":
			table = T_KORP
			count = rng.randi_range(2, 3)
	return _roll_table(table, count, rng, biome)


static func _roll_table(table: Array, count: int, rng: RandomNumberGenerator, biome: String) -> Array:
	var out := []
	for i in count:
		out.append(_make(_pick(rng, table), rng, biome))
	return out
