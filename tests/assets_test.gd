extends SceneTree
## Test zasobów: wszystkie dźwięki i grafiki używane w kodzie istnieją i się wczytują.

func _initialize() -> void:
	var fails := 0
	var sounds := {}
	var re := RegEx.new()
	re.compile("Audio\\.(?:play|play_at|ambient|layer)\\(\"([a-z_0-9]+)\"")
	for dir in ["res://scripts", "res://scripts/raid", "res://scripts/ui", "res://autoload"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var src := FileAccess.get_file_as_string(dir + "/" + f)
			for m in re.search_all(src):
				if not m.get_string(1).ends_with("_"):  # nazwy składane dynamicznie sprawdzamy niżej
					sounds[m.get_string(1)] = true
	for c in ["a", "b", "c"]:
		for p in ["bark_", "radio_", "shot_enemy_"]:
			sounds[p + c] = true
	for i in 3:
		sounds["step_%d" % i] = true
	for s in ["shot_rifle", "shot_smg", "shot_pistol", "shot_dmr", "amb_suburb", "amb_lab", "amb_base", "anomaly_whisper", "bandage", "injector"]:
		sounds[s] = true
	for s in sounds:
		var st := Assets.sound(s)
		if st == null or st.get_length() <= 0.0:
			fails += 1
			print("FAIL dźwięk ", s)
	print("dźwięków sprawdzono: ", sounds.size())
	var texes := ["player", "szab", "najem", "wojsk", "elita", "fauna", "corpse_player", "corpse_szab", "corpse_najem",
		"corpse_wojsk", "corpse_elita", "corpse_fauna", "box_anomalia", "wall_a", "wall_b", "cover_a", "cover_b",
		"exit_frame", "floor_x0", "floor_x1"]
	for t in ["a", "b"]:
		for i in 4:
			texes.append("floor_%s%d" % [t, i])
		for k in ["szafka", "skrzynia", "biurko", "sejf"]:
			texes.append("box_%s_%s" % [t, k])
	for t in texes:
		var tx := Assets.tex(t)
		if tx == null or tx.get_width() < 4:
			fails += 1
			print("FAIL grafika ", t)
	print("grafik sprawdzono: ", texes.size())
	print("ASSETS TEST ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
