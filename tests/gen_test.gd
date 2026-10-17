extends SceneTree
## Test generatora: dla wielu ziaren wszystkie wyjścia i łup są osiągalne, wrogowie poza startem.

func _initialize() -> void:
	var fails := 0
	var total_loot := 0
	var total_spawns := 0
	for seed_value in range(1, 41):
		var gen := LevelGen.new()
		var r := gen.generate(seed_value)
		var nav := GridNav.new(r["rows"], 32)
		var start: Vector2 = r["start"]
		if r["exits"].size() < 2:
			fails += 1; print("FAIL exits count seed ", seed_value)
		for e in r["exits"]:
			if nav.find_path(start, e["pos"]).is_empty():
				fails += 1; print("FAIL exit unreachable seed ", seed_value)
		for l in r["loot"]:
			if nav.find_path(start, l).is_empty():
				fails += 1; print("FAIL loot unreachable seed ", seed_value)
		if r["loot"].size() < 12:
			fails += 1; print("FAIL loot count ", r["loot"].size(), " seed ", seed_value)
		for s in r["spawns"]:
			for c in s["cells"]:
				if c.distance_to(start) < 64.0:
					fails += 1; print("FAIL spawn near start seed ", seed_value)
		total_loot += r["loot"].size()
		total_spawns += r["spawns"].size()
	print("avg loot ", total_loot / 40.0, " avg groups ", total_spawns / 40.0)
	print("GEN TEST ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
