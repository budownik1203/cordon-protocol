class_name Biomes
extends RefCounted
## Definicje biomów: rozmiar poziomu, wrogowie, paleta, nazwy kontenerów, dźwięk tła.

const ORDER := ["przedmiescia", "kompleks"]

const DEFS := {
	"szkolenie": {
		"name": "Poligon szkoleniowy", "short": "Szkolenie", "cols": 3, "rows": 1, "rooms": [3, 3],
		"tiles": "a", "ambient": Color(0.2, 0.2, 0.24), "ambient_sound": "amb_base",
		"factions": {}, "anomaly": false, "elite": "", "fauna_period": 9999.0,
		"kind_names": {"szafka": "Szafka szkoleniowa", "skrzynia": "Skrzynia", "biurko": "Biurko", "sejf": "Sejf"},
		"desc": "Krótki rajd szkoleniowy. Nic z niego nie przepada.", "unlock": "",
	},
	"przedmiescia": {
		"name": "Opuszczone przedmieścia", "short": "Przedmieścia", "cols": 4, "rows": 3, "rooms": [8, 10],
		"tiles": "a", "ambient": Color(0.12, 0.12, 0.15), "ambient_sound": "amb_suburb",
		"factions": {"Szabrownicy": 0.55, "Najemnicy": 0.27, "Wojskowi": 0.18},
		"anomaly": false, "elite": "Dowódca posterunku", "fauna_period": 45.0,
		"kind_names": {"szafka": "Szafka", "skrzynia": "Skrzynia", "biurko": "Biurko", "sejf": "Sejf"},
		"desc": "Osiedle sprzed zamknięcia. Szabrownicy, patrole Najemników i posterunek Wojskowych przy bramie.",
		"unlock": "",
	},
	"kompleks": {
		"name": "Kompleks badawczy", "short": "Kompleks", "cols": 5, "rows": 3, "rooms": [10, 12],
		"tiles": "b", "ambient": Color(0.1, 0.12, 0.14), "ambient_sound": "amb_lab",
		"factions": {"Najemnicy": 0.5, "Wojskowi": 0.42, "Szabrownicy": 0.08},
		"anomaly": true, "elite": "Oficer ochrony", "fauna_period": 38.0,
		"kind_names": {"szafka": "Szafa laboratoryjna", "skrzynia": "Skrzynia transportowa",
			"biurko": "Terminal", "sejf": "Sejf laboratoryjny", "anomalia": "Coś w rogu"},
		"desc": "Laboratoria, regały serwerowe i pokój, który się powtarza. Najemnicy i Wojskowi. Więcej dokumentów, drożej, głośniej.",
		"unlock": "przedmiescia",
	},
}


static func get_def(id: String) -> Dictionary:
	return DEFS.get(id, DEFS["przedmiescia"])


static func kind_name(biome: String, kind: String) -> String:
	return get_def(biome).get("kind_names", {}).get(kind, kind.capitalize())
