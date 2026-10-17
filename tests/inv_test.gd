extends SceneTree
## Test ekwipunku: siatka, obrót, redukcja wagi, serializacja.

func _initialize() -> void:
	var fails := 0
	var bag := Bag.grid(4, 3)
	var rifle := Item.new("rifle_skm")  # 5x2 nie mieści się w 4x3 (nawet obrócone 2x5)
	if bag.add_auto(rifle):
		fails += 1; print("FAIL rifle fits 4x3")
	var smg := Item.new("smg_kr")  # 3x2
	if not bag.add_auto(smg):
		fails += 1; print("FAIL smg")
	var pistol := Item.new("pistol_p9")  # 2x1
	if not bag.add_auto(pistol):
		fails += 1; print("FAIL pistol")
	if bag.fits(Item.new("pistol_p9"), smg.x, smg.y):
		fails += 1; print("FAIL overlap")
	# stack
	var b2 := Bag.grid(2, 1)
	b2.add_auto(Item.new("ammo_9", 50))
	b2.add_auto(Item.new("ammo_9", 30))
	if b2.items.size() != 2 or b2.count_of("ammo_9") != 80:
		fails += 1; print("FAIL stacking ", b2.items.size(), " ", b2.count_of("ammo_9"))
	# redukcja wagi: ten sam ładunek w plecakach A i B
	var load_a := Item.new("backpack_a")
	var load_b := Item.new("backpack_b")
	for bp in [load_a, load_b]:
		bp.bag.add_auto(Item.new("ammo_556", 60))
		bp.bag.add_auto(Item.new("radio"))
	var wa: float = load_a.bag.effective_weight()
	var wb: float = load_b.bag.effective_weight()
	var raw: float = load_a.bag.raw_weight()
	if not (absf(wa - raw * 0.7) < 0.001 and absf(wb - raw * 0.55) < 0.001 and wb < wa):
		fails += 1; print("FAIL reduction ", wa, " ", wb, " ", raw)
	# kształt pojemnika (dziury w układzie)
	var rig := Item.new("rig_a")
	if rig.bag.cell_count() != 13:
		fails += 1; print("FAIL rig cells ", rig.bag.cell_count())
	if rig.bag.fits(Item.new("ammo_9"), 2, 0):
		fails += 1; print("FAIL hole")
	# serializacja
	var eq := Equipment.new()
	eq.equip("backpack", load_a)
	eq.equip("primary", rifle)
	var data := JSON.stringify(eq.to_dict())
	var eq2 := Equipment.new()
	eq2.from_dict(JSON.parse_string(data))
	if absf(eq2.total_weight() - eq.total_weight()) > 0.001:
		fails += 1; print("FAIL serialize ", eq2.total_weight(), " ", eq.total_weight())
	# progi obciążenia
	if eq.load_level() > 1:
		print("note load level ", eq.load_level(), " w=", eq.total_weight())
	print("INV TEST ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
