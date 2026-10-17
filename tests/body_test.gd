extends SceneTree
## Test modelu ciała w stylu Tarkova: części, bleedy, złamania, zniszczone kończyny, operacja, apteczka.

var fails := 0


func _ok(c: bool, m: String) -> void:
	if not c:
		fails += 1
		print("FAIL ", m)


func _initialize() -> void:
	seed(3)
	# hełm klasy 2 vs penetracja 3 – część obrażeń przechodzi
	var b := Body.new()
	b.helmet = ArmorData.make("Hełm", 2, 40.0)
	var dealt := b.apply_hit(Body.Part.HEAD, 20.0, 3)
	_ok(dealt < 20.0 and dealt > 5.0, "helmet %f" % dealt)

	# krwawienie jest per część i zatrzymuje je bandaż / opaska
	var c := Body.new()
	c.bleed[Body.Part.L_LEG] = 2
	c.tick(5.0)
	_ok(c.hp[Body.Part.L_LEG] < 65.0 and c.hp[Body.Part.CHEST] == 85.0, "bleed per part")
	_ok(not c.use_bandage(Body.Part.L_LEG), "bandaż nie zatrzymuje ciężkiego")
	_ok(c.use_hemostatic(Body.Part.L_LEG), "opaska zatrzymuje ciężkie")
	var before: float = c.hp[Body.Part.L_LEG]
	c.tick(30.0)
	_ok(c.hp[Body.Part.L_LEG] == before, "po opasce nie krwawi")
	c.bleed[Body.Part.R_ARM] = 1
	_ok(c.use_bandage(Body.Part.R_ARM), "bandaż na lekkie")

	# krwawienie z klatki prowadzi do śmierci
	var d := Body.new()
	d.bleed[Body.Part.CHEST] = 2
	var t := 0.0
	while d.alive and t < 400.0:
		d.tick(0.5)
		t += 0.5
	_ok(not d.alive and d.cause_of_death == "Wykrwawienie", "wykrwawienie klatki: %s" % d.cause_of_death)

	# zniszczenie klatki i głowy = śmierć
	var e := Body.new()
	e.apply_hit(Body.Part.CHEST, 500.0, 6)
	_ok(not e.alive, "chest death")
	var e2 := Body.new()
	e2.apply_hit(Body.Part.HEAD, 500.0, 6)
	_ok(not e2.alive, "head death")

	# zniszczona noga: nie śmierć, złamanie, wolniej, bez sprintu; nadmiar rozchodzi się na ciało
	var f := Body.new()
	f.apply_hit(Body.Part.L_LEG, 100.0, 6)
	_ok(f.alive and f.blacked(Body.Part.L_LEG), "noga zniszczona, żyje")
	_ok(f.hp[Body.Part.CHEST] < 85.0 and f.hp[Body.Part.HEAD] == 35.0, "nadmiar na ciało bez głowy")
	_ok(f.speed_mult() < 0.65 and not f.can_sprint(), "zniszczona noga spowalnia")
	_ok(not f.use_splint(Body.Part.L_LEG), "szyna nie naprawia zniszczonej")
	_ok(not f.heal(Body.Part.L_LEG, 30.0) > 0.0, "apteczka nie leczy zniszczonej")

	# operacja przywraca kończynę z karą do maks. HP
	_ok(f.use_surgery(Body.Part.L_LEG), "operacja")
	_ok(not f.blacked(Body.Part.L_LEG) and f.max_hp[Body.Part.L_LEG] < 65.0, "po operacji kara maks HP")
	_ok(f.heal(Body.Part.L_LEG, 100.0) > 0.0 and f.hp[Body.Part.L_LEG] <= f.max_hp[Body.Part.L_LEG] + 0.01, "leczenie do nowego maksimum")

	# złamanie: szyna naprawia; tabletki łagodzą
	var g := Body.new()
	g.fracture[Body.Part.R_LEG] = true
	var slow := g.speed_mult()
	g.use_painkiller()
	_ok(g.speed_mult() > slow, "tabletki łagodzą złamanie")
	_ok(g.use_splint(Body.Part.R_LEG) and g.speed_mult() > 0.99, "szyna naprawia złamanie")

	# auto-cel
	var h := Body.new()
	h.bleed[Body.Part.STOMACH] = 1
	h.bleed[Body.Part.L_ARM] = 2
	_ok(h.auto_target("hemostatic") == Body.Part.L_ARM, "auto cel hemostat")
	_ok(h.auto_target("bandage") == Body.Part.STOMACH, "auto cel bandaż")
	_ok(h.auto_target("splint") == -1, "nic do szynowania")

	print("BODY TEST ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
