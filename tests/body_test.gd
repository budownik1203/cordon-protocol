extends SceneTree
## Test modelu ciała: krwawienie, leczenie, śmierć, pancerz.

func _initialize() -> void:
	var fails := 0
	seed(3)
	var b := Body.new()
	# głowa: hełm klasy 2 vs penetracja 3 – część obrażeń przechodzi
	b.helmet = ArmorData.make("Hełm", 2, 40.0)
	var dealt := b.apply_hit(Body.Part.HEAD, 20.0, 3)
	if not (dealt < 20.0 and dealt > 5.0):
		fails += 1; print("FAIL helmet ", dealt)
	# ciężkie krwawienie prowadzi do wykrwawienia
	var c := Body.new()
	c.heavy_bleeds = 1
	var t := 0.0
	while c.alive and t < 200.0:
		c.tick(0.5); t += 0.5
	if c.alive or c.cause_of_death != "Wykrwawienie":
		fails += 1; print("FAIL bleed ", c.cause_of_death)
	# hemostatyk zatrzymuje krwawienie
	var d := Body.new()
	d.heavy_bleeds = 1
	d.use_hemostatic()
	d.tick(60.0)
	if d.blood < 100.0:
		fails += 1; print("FAIL hemostatic")
	# zniszczenie klatki = śmierć
	var e := Body.new()
	e.apply_hit(Body.Part.CHEST, 500.0, 6)
	if e.alive:
		fails += 1; print("FAIL chest death")
	# złamanie nogi spowalnia, szyna naprawia
	var f := Body.new()
	f.leg_fracture = true
	var slow := f.speed_mult()
	f.use_splint()
	if not (slow < 0.7 and f.speed_mult() > 0.99):
		fails += 1; print("FAIL fracture")
	print("BODY TEST ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
