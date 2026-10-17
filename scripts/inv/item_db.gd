class_name ItemDB
extends RefCounted
## Baza przedmiotów (dane). Docelowo przeniesiona do zasobów .tres / JSON.
## Klucze: name, w, h, weight (kg za sztukę), value (bony), stack, type, slot, ...

static var _defs: Dictionary = {}

const DOCS := [
	"RAPORT 14/B. Obiekt reaguje na obecność personelu. Zalecamy ograniczenie obecności personelu. Obiekt reaguje.",
	"Notatka służbowa: Prosimy nie otwierać drzwi oznaczonych czerwonym pasem. Drzwi były już otwierane. Proszę o wyjaśnienia na piśmie.",
	"Protokół ewakuacji, pkt 4: w razie powtarzania się pomieszczeń, nie wchodzić do pomieszczenia, które już Pan(i) widział(a).",
	"Dziennik: Dzień 212 w kwarantannie. Pies sąsiada wrócił. Sąsiad nie wrócił. Pies ma teraz więcej łap.",
	"Zarządzenie wewnętrzne: wszelkie przypadki 'przejścia' należy kwalifikować jako awarię wentylacji.",
	"Nagranie 7: Doktor mówi, że to nie eksperyment, tylko 'otwarcie'. Kierownik prosi, by nie używać tego słowa na piśmie.",
	"Notatka: Kordon utrzymany. Kordon utrzymany. Kordon utrzymany. Kordon utrzymany. (Podpis nieczytelny, pisane jedną ręką).",
	"Raport medyczny: pacjent twierdzi, że widzi korytarz zza korytarza. Wypisano. Powrót w trybie pilnym.",
	"Do: Zarząd. Od: Dział Bezpieczeństwa. Temat: wzrost zapotrzebowania na latarki. Odmowa: koszty.",
	"Ogłoszenie: Kółko wzajemnej adoracji przy Przejściu spotyka się we wtorki. Prosimy nie przynosić świec.",
]

const DOCS_LAB := [
	"Protokół: pomieszczenie 3-C powtarza się co 40 metrów. Prosimy zgłaszać każdy napotkany egzemplarz pracownikom.",
	"Notatka: Próbka nr 88 nie jest już próbką. Próbka nr 88 prosi, by tak jej nie nazywać.",
	"Do: Zespół Badawczy. Temat: zgoda na eksperyment 'Otwarcie'. Zgoda udzielona z opóźnieniem. Skutki poprzedziły zgodę.",
	"Wewnętrzne: windy zjeżdżają na poziomy, których nie ma w planach. Windy nie mają dokąd wrócić.",
	"Dziennik dr K.: Rano był wtorek. Po południu był wtorek. Wieczorem kierownik pyta, czemu nie złożyłem raportu z poniedziałku.",
	"Regulamin: w razie spotkania własnego sobowtóra prosimy nie podawać ręki. Podpisać protokół i się rozejść.",
	"Biuro Zakupów: zamówiono 400 kg soli. Powód: 'na wszelki wypadek'. Sól zużyto w ciągu tygodnia.",
	"Nagranie 12: słychać kroki z korytarza. Kamera pokazuje pusty korytarz. Kroki słychać też na nagraniu z poprzedniego dnia.",
	"Zawiadomienie: personel zaginiony w strefie B uznaje się za obecny. Wypłaty będą realizowane zgodnie z grafikiem.",
	"Karta pacjenta 0: wyniki w normie. Pacjent 0 nie był pacjentem. Pacjent 0 jest wymieniony w 14 raportach z przyszłości.",
]


static func _build() -> void:
	if not _defs.is_empty():
		return
	# Amunicja
	_add("ammo_556", {"name": "Amunicja 5.56", "w": 1, "h": 1, "weight": 0.02, "value": 4, "stack": 60,
		"type": "ammo", "ammo_type": "556", "pen": 3, "color": Color(0.8, 0.7, 0.3)})
	_add("ammo_9", {"name": "Amunicja 9 mm", "w": 1, "h": 1, "weight": 0.012, "value": 2, "stack": 60,
		"type": "ammo", "ammo_type": "9", "pen": 2, "color": Color(0.75, 0.6, 0.3)})
	# Magazynki: zawartość to pole `loaded` egzemplarza (naboje), zawsze jeden rodzaj amunicji.
	_add("mag_556_30", {"name": "Magazynek 5.56 (30)", "w": 1, "h": 2, "weight": 0.25, "value": 90, "stack": 1,
		"type": "mag", "ammo_type": "556", "cap": 30, "color": Color(0.5, 0.52, 0.4)})
	_add("mag_9_32", {"name": "Magazynek 9 mm (32)", "w": 1, "h": 2, "weight": 0.2, "value": 70, "stack": 1,
		"type": "mag", "ammo_type": "9", "cap": 32, "color": Color(0.48, 0.5, 0.42)})
	_add("mag_9_12", {"name": "Magazynek P-9 (12)", "w": 1, "h": 1, "weight": 0.1, "value": 40, "stack": 1,
		"type": "mag", "ammo_type": "9", "cap": 12, "color": Color(0.46, 0.48, 0.44)})
	_add("mag_762_10", {"name": "Magazynek 7.62 (10)", "w": 1, "h": 2, "weight": 0.3, "value": 160, "stack": 1,
		"type": "mag", "ammo_type": "762", "cap": 10, "color": Color(0.52, 0.45, 0.35)})
	# Leczenie
	_add("bandage", {"name": "Bandaż (lekkie krwawienie)", "w": 1, "h": 1, "weight": 0.1, "value": 30, "stack": 4,
		"type": "med", "heal": "bandage", "use_time": 3.0, "color": Color(0.85, 0.85, 0.85)})
	_add("hemostatic", {"name": "Opaska hemostatyczna (ciężkie krwawienie)", "w": 1, "h": 1, "weight": 0.1, "value": 80, "stack": 2,
		"type": "med", "heal": "hemostatic", "use_time": 4.0, "color": Color(0.8, 0.25, 0.25)})
	_add("splint", {"name": "Szyna (złamanie)", "w": 1, "h": 2, "weight": 0.3, "value": 60, "stack": 1,
		"type": "med", "heal": "splint", "use_time": 6.0, "color": Color(0.6, 0.5, 0.3)})
	_add("painkiller", {"name": "Środek przeciwbólowy (całe ciało)", "w": 1, "h": 1, "weight": 0.05, "value": 50, "stack": 4,
		"type": "med", "heal": "painkiller", "use_time": 2.0, "color": Color(0.3, 0.6, 0.85)})
	_add("medkit", {"name": "Apteczka IFAK (leczy HP części)", "w": 2, "h": 1, "weight": 0.4, "value": 260, "stack": 1,
		"type": "med", "heal": "medkit", "use_time": 4.0, "durability": 150.0, "color": Color(0.8, 0.3, 0.3)})
	_add("surgery", {"name": "Zestaw chirurgiczny (naprawa zniszczonej kończyny)", "w": 2, "h": 2, "weight": 0.6, "value": 900, "stack": 1,
		"type": "med", "heal": "surgery", "use_time": 14.0, "color": Color(0.3, 0.65, 0.65)})
	# Bronie
	_add("rifle_skm", {"name": "Karabin SKM-74", "w": 5, "h": 2, "weight": 3.6, "value": 900, "stack": 1,
		"type": "weapon", "slot": "primary", "ammo_type": "556", "mag_id": "mag_556_30", "color": Color(0.35, 0.4, 0.35),
		"weapon": {"name": "SKM-74", "damage": 32.0, "rpm": 600.0, "mag": 30, "reload": 2.4, "spread": 0.9,
			"move_spread": 4.0, "recoil": 0.9, "recovery": 6.0, "range": 620.0, "noise": 320.0, "snd": "shot_rifle"}})
	_add("smg_kr", {"name": "Pistolet maszynowy KR-9", "w": 3, "h": 2, "weight": 2.5, "value": 600, "stack": 1,
		"type": "weapon", "slot": "primary", "ammo_type": "9", "mag_id": "mag_9_32", "color": Color(0.35, 0.38, 0.4),
		"weapon": {"name": "KR-9", "damage": 19.0, "rpm": 800.0, "mag": 32, "reload": 2.0, "spread": 1.4,
			"move_spread": 3.0, "recoil": 0.8, "recovery": 6.5, "range": 380.0, "noise": 240.0, "snd": "shot_smg"}})
	_add("pistol_p9", {"name": "Pistolet P-9", "w": 2, "h": 1, "weight": 0.9, "value": 250, "stack": 1,
		"type": "weapon", "slot": "pistol", "ammo_type": "9", "mag_id": "mag_9_12", "color": Color(0.3, 0.3, 0.35),
		"weapon": {"name": "P-9", "damage": 22.0, "rpm": 330.0, "mag": 12, "reload": 1.6, "spread": 1.2,
			"move_spread": 2.5, "recoil": 1.2, "recovery": 7.0, "range": 340.0, "noise": 200.0, "snd": "shot_pistol"}})
	# Rzadsze rzeczy z głębszych biomów
	_add("ammo_762", {"name": "Amunicja 7.62", "w": 1, "h": 1, "weight": 0.025, "value": 9, "stack": 40,
		"type": "ammo", "ammo_type": "762", "pen": 4, "color": Color(0.85, 0.55, 0.25)})
	_add("dmr_sw", {"name": "Karabin wyborowy SW-76", "w": 6, "h": 2, "weight": 4.4, "value": 2400, "stack": 1,
		"type": "weapon", "slot": "primary", "ammo_type": "762", "mag_id": "mag_762_10", "color": Color(0.3, 0.33, 0.3),
		"weapon": {"name": "SW-76", "damage": 55.0, "rpm": 190.0, "mag": 10, "reload": 3.0, "spread": 0.5,
			"move_spread": 6.0, "recoil": 2.4, "recovery": 5.0, "range": 820.0, "noise": 380.0, "snd": "shot_dmr"}})
	_add("helmet_4", {"name": "Hełm kl. 4", "w": 2, "h": 2, "weight": 1.9, "value": 2000, "stack": 1,
		"type": "armor", "slot": "head", "armor_class": 4, "durability": 60.0, "color": Color(0.32, 0.45, 0.35)})
	_add("armor_5", {"name": "Kamizelka kuloodporna kl. 5", "w": 3, "h": 3, "weight": 8.5, "value": 4200, "stack": 1,
		"type": "armor", "slot": "armor", "armor_class": 5, "durability": 110.0, "color": Color(0.25, 0.3, 0.5)})
	# Pancerz
	_add("helmet_2", {"name": "Hełm kl. 2", "w": 2, "h": 2, "weight": 1.2, "value": 400, "stack": 1,
		"type": "armor", "slot": "head", "armor_class": 2, "durability": 40.0, "color": Color(0.4, 0.45, 0.35)})
	_add("helmet_3", {"name": "Hełm kl. 3", "w": 2, "h": 2, "weight": 1.6, "value": 900, "stack": 1,
		"type": "armor", "slot": "head", "armor_class": 3, "durability": 50.0, "color": Color(0.4, 0.5, 0.35)})
	_add("armor_3", {"name": "Kamizelka kuloodporna kl. 3", "w": 3, "h": 3, "weight": 3.5, "value": 800, "stack": 1,
		"type": "armor", "slot": "armor", "armor_class": 3, "durability": 60.0, "color": Color(0.35, 0.4, 0.5)})
	_add("armor_4", {"name": "Kamizelka kuloodporna kl. 4", "w": 3, "h": 3, "weight": 5.0, "value": 1800, "stack": 1,
		"type": "armor", "slot": "armor", "armor_class": 4, "durability": 80.0, "color": Color(0.3, 0.35, 0.55)})
	# Pojemniki
	_add("backpack_a", {"name": "Plecak Szturmowy (24 miejsca, -30% wagi)", "w": 4, "h": 5, "weight": 1.2, "value": 500,
		"stack": 1, "type": "container", "slot": "backpack", "reduction": 0.30, "color": Color(0.45, 0.4, 0.3),
		"layout": ["XXXXXX", "XXXXXX", "XXXXXX", "XXXXXX"]})
	_add("backpack_b", {"name": "Plecak Kompaktowy (12 miejsc, -45% wagi)", "w": 3, "h": 4, "weight": 0.8, "value": 650,
		"stack": 1, "type": "container", "slot": "backpack", "reduction": 0.45, "color": Color(0.4, 0.45, 0.35),
		"layout": ["XXXX", "XXXX", "XXXX"]})
	_add("rig_a", {"name": "Kamizelka taktyczna Szeregowa", "w": 3, "h": 3, "weight": 0.9, "value": 350, "stack": 1,
		"type": "container", "slot": "rig", "reduction": 0.15, "color": Color(0.35, 0.4, 0.38),
		"layout": ["XX.XX", "XXXXX", "XX.XX"]})
	_add("rig_b", {"name": "Ładownica Lekka", "w": 3, "h": 2, "weight": 0.5, "value": 250, "stack": 1,
		"type": "container", "slot": "rig", "reduction": 0.25, "color": Color(0.38, 0.4, 0.33),
		"layout": ["XXXX", "XXXX"]})
	_add("belt_a", {"name": "Pas Taktyczny", "w": 4, "h": 1, "weight": 0.4, "value": 180, "stack": 1,
		"type": "container", "slot": "belt", "reduction": 0.20, "color": Color(0.4, 0.35, 0.3),
		"layout": ["XXXX"]})
	_add("secure_a", {"name": "Bezpieczny kontener", "w": 2, "h": 2, "weight": 0.2, "value": 1500, "stack": 1,
		"type": "container", "slot": "secure", "reduction": 1.0, "color": Color(0.7, 0.6, 0.2),
		"layout": ["XXX", "XXX"]})
	# Łupy
	_add("watch", {"name": "Zegarek", "w": 1, "h": 1, "weight": 0.1, "value": 140, "stack": 1, "type": "loot", "color": Color(0.8, 0.8, 0.4)})
	_add("radio", {"name": "Radio polowe", "w": 2, "h": 2, "weight": 1.2, "value": 380, "stack": 1, "type": "loot", "color": Color(0.5, 0.55, 0.4)})
	_add("battery", {"name": "Akumulator", "w": 2, "h": 1, "weight": 0.9, "value": 170, "stack": 1, "type": "loot", "color": Color(0.45, 0.5, 0.55)})
	_add("tape", {"name": "Kaseta z nagraniem", "w": 1, "h": 1, "weight": 0.05, "value": 90, "stack": 1, "type": "loot", "color": Color(0.4, 0.4, 0.45)})
	_add("lamp", {"name": "Latarka ręczna", "w": 1, "h": 2, "weight": 0.4, "value": 120, "stack": 1, "type": "loot", "color": Color(0.7, 0.7, 0.5)})
	_add("sample", {"name": "Próbka (korporacyjna)", "w": 1, "h": 2, "weight": 0.3, "value": 600, "stack": 1, "type": "loot", "color": Color(0.5, 0.8, 0.7)})
	_add("document", {"name": "Dokument", "w": 1, "h": 1, "weight": 0.02, "value": 50, "stack": 1, "type": "doc", "color": Color(0.9, 0.9, 0.8)})
	_add("datacard", {"name": "Karta dostępu laboratorium", "w": 1, "h": 1, "weight": 0.02, "value": 450, "stack": 1, "type": "loot", "color": Color(0.3, 0.7, 0.9)})
	_add("key_exit", {"name": "Klucz do bramy kordonu", "w": 1, "h": 1, "weight": 0.05, "value": 400, "stack": 1, "type": "key", "color": Color(0.9, 0.8, 0.2)})


static func _add(id: String, d: Dictionary) -> void:
	d["id"] = id
	_defs[id] = d


static func get_def(id: String) -> Dictionary:
	_build()
	return _defs.get(id, {})


static func all_ids() -> Array:
	_build()
	return _defs.keys()


static func random_doc(biome: String = "przedmiescia") -> String:
	var pool: Array = DOCS_LAB if biome == "kompleks" else DOCS
	return pool[randi() % pool.size()]
