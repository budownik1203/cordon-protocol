class_name Quests
extends RefCounted
## Zadania handlarzy: łańcuchy po trzy na handlarza. Typy: deliver (oddaj przedmioty), kill (zabij frakcję/elitę),
## extract (ewakuuj się z biomu). Za każde zadanie gracz wybiera jedną z dwóch nagród.

const LIST := [
	# --- Chorąży Wójt (zbrojmistrz) ---
	{"id": "kw1", "trader": "kw", "title": "Inwentaryzacja", "type": "deliver", "item": "radio", "n": 2,
		"text": "Magazyn mi się nie zgadza. Brakuje dwóch radiostacji polowych. Przynieś dwie, a ja nie zapytam skąd.",
		"rewards": [{"label": "900 bonów", "money": 900}, {"label": "90 szt. amunicji 5.56 i 60 szt. 9 mm", "items": [["ammo_556", 90], ["ammo_9", 60]]}]},
	{"id": "kw2", "trader": "kw", "title": "Czyszczenie terenu", "type": "kill", "faction": "Najemnicy", "n": 3,
		"text": "Najemnicy podkradają mi klientów. Zdejmij trzech. Nie, nie będzie rachunku.",
		"alt": "Skoro wolisz amunicję od pieniędzy, to masz fach w ręku. Zdejmij trzech Najemników.",
		"rewards": [{"label": "1400 bonów", "money": 1400}, {"label": "Hełm kl. 3 i kamizelka kl. 3", "items": [["helmet_3", 1], ["armor_3", 1]]}]},
	{"id": "kw3", "trader": "kw", "title": "Dług honorowy", "type": "kill", "faction": "Elita", "n": 1,
		"text": "Dowódca przy bramie wisi mi klucz i jeszcze parę drobiazgów. Zdejmij oficera dowodzącego, w dowolnym kordonie.",
		"rewards": [{"label": "3000 bonów", "money": 3000}, {"label": "Kamizelka kl. 4 i hełm kl. 3", "items": [["armor_4", 1], ["helmet_3", 1]]}]},
	# --- Doktor Ruda (medyk) ---
	{"id": "med1", "trader": "med", "title": "Zapasy", "type": "deliver", "item": "bandage", "n": 4,
		"text": "Zostały mi opatrunki, których nie da się dzielić na pół. Przynieś cztery bandaże, proszę.",
		"rewards": [{"label": "600 bonów", "money": 600}, {"label": "3 hemostatyki i 3 środki przeciwbólowe", "items": [["hemostatic", 3], ["painkiller", 3]]}]},
	{"id": "med2", "trader": "med", "title": "Próbki do analizy", "type": "deliver", "item": "sample", "n": 2,
		"text": "Potrzebuję dwóch próbek z kompleksu. Nie pytaj, po co. Wiem, po co. To mnie właśnie martwi.",
		"alt": "Nie dziękowałem, ale dziękuję. Dwie próbki jeszcze, dla porównania.",
		"rewards": [{"label": "1500 bonów", "money": 1500}, {"label": "Zestaw medyczny (szyny, hemostatyki, bandaże)", "items": [["splint", 2], ["hemostatic", 4], ["bandage", 4]]}]},
	{"id": "med3", "trader": "med", "title": "Karty pacjentów", "type": "deliver", "item": "document", "n": 3,
		"text": "Trzy dokumenty. Dowolne. Chcę sprawdzić, czy ktoś jeszcze pisze o tym samym, co ja pamiętam.",
		"rewards": [{"label": "1200 bonów", "money": 1200}, {"label": "Zapas leków (hemostatyki, środki przeciwbólowe, szyna)", "items": [["hemostatic", 4], ["painkiller", 4], ["splint", 1]]}]},
	# --- Sznurek (skup, pośrednik) ---
	{"id": "pos1", "trader": "pos", "title": "Zegarki", "type": "deliver", "item": "watch", "n": 3,
		"text": "Ludzie chcą wiedzieć, która godzina. Przynieś trzy zegarki, zrobię ludziom dobrze.",
		"rewards": [{"label": "700 bonów", "money": 700}, {"label": "Plecak Szturmowy", "items": [["backpack_a", 1]]}]},
	{"id": "pos2", "trader": "pos", "title": "Konkurencja", "type": "extract", "biome": "kompleks", "n": 1,
		"text": "Ktoś sprzedaje próbki z kompleksu taniej niż ja. Wróć stamtąd żywy, zobaczymy, kto.",
		"alt": "Pieniądze to pieniądze, ale ja lubię ludzi, którzy wracają. Wróć z kompleksu.",
		"rewards": [{"label": "1800 bonów", "money": 1800}, {"label": "Dwa klucze do bramy kordonu", "items": [["key_exit", 2]]}]},
	{"id": "pos3", "trader": "pos", "title": "Kolekcja", "type": "deliver", "item": "datacard", "n": 2,
		"text": "Znam kolekcjonera. Płaci za dziwactwa. Dwie karty dostępu z laboratorium, to wystarczy.",
		"rewards": [{"label": "2000 bonów", "money": 2000}, {"label": "Karabin wyborowy SW-76", "items": [["dmr_sw", 1]]}]},
]


static func get_quest(id: String) -> Dictionary:
	for q in LIST:
		if q["id"] == id:
			return q
	return {}


static func for_trader(trader: String) -> Array:
	return LIST.filter(func(q): return q["trader"] == trader)
