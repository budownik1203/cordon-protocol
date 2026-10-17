extends SceneTree
## Test generatora: dla wielu ziaren i biomów wszystkie wyjścia i łup są osiągalne, wrogowie poza startem,
## elita w pokoju z kluczowym wyjściem, pokój anomalii w kompleksie, szkolenie bez wrogów.

func _initialize() -> void:
	var fails := 0
	for biome in ["przedmiescia", "kompleks"]:
		var total_loot := 0
		var total_spawns := 0
		for seed_value in range(1, 41):
			var gen := LevelGen.new()
			var r := gen.generate(seed_value, biome)
			var nav := GridNav.new(r["rows"], 32)
			var start: Vector2 = r["start"]
			if r["exits"].size() < 2:
				fails += 1; print("FAIL exits count ", biome, " seed ", seed_value)
			for e in r["exits"]:
				if nav.find_path(start, e["pos"]).is_empty():
					fails += 1; print("FAIL exit unreachable ", biome, " seed ", seed_value)
			for l in r["loot"]:
				if nav.find_path(start, l).is_empty():
					fails += 1; print("FAIL loot unreachable ", biome, " seed ", seed_value)
			if r["loot"].size() < 12:
				fails += 1; print("FAIL loot count ", r["loot"].size(), " ", biome, " seed ", seed_value)
			var elites := 0
			for s in r["spawns"]:
				if s.get("elite", false):
					elites += 1
				for c in s["cells"]:
					if c.distance_to(start) < 64.0:
						fails += 1; print("FAIL spawn near start ", biome, " seed ", seed_value)
					if nav.find_path(start, c).is_empty():
						fails += 1; print("FAIL spawn unreachable ", biome, " seed ", seed_value)
			if elites != 1:
				fails += 1; print("FAIL elites=", elites, " ", biome, " seed ", seed_value)
			if biome == "kompleks":
				if r["anomaly_room"].x < 0 or r["anomaly_loot"].is_empty():
					fails += 1; print("FAIL anomaly seed ", seed_value)
				for f in r["spawns"]:
					if f["faction"] == "Szabrownicy" and f.get("elite", false):
						fails += 1
			total_loot += r["loot"].size()
			total_spawns += r["spawns"].size()
		print(biome, ": avg loot ", total_loot / 40.0, " avg groups ", total_spawns / 40.0)
	# szkolenie
	for seed_value in range(1, 11):
		var r2 := LevelGen.new().generate(seed_value, "szkolenie")
		var nav2 := GridNav.new(r2["rows"], 32)
		if r2["exits"].size() != 1 or not r2["spawns"].is_empty() or not r2.has("tutorial"):
			fails += 1; print("FAIL tutorial structure")
		var t: Dictionary = r2["tutorial"]
		for p in t["targets"] + [t["box"], t["enemy"], r2["exits"][0]["pos"]]:
			if nav2.find_path(r2["start"], p).is_empty():
				fails += 1; print("FAIL tutorial unreachable ", p)
	print("GEN TEST ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
