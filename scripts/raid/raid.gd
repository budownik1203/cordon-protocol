extends Node2D
## Rajd: losowy układ pokoi (biom), światło i stożek widzenia, wrogowie z elitą, łup, ciało z poprzedniej śmierci,
## mapa z mgłą wojny, ewakuacja, raport. Tryb szkolenia: krótki poligon z podpowiedziami.

const TILE := 32
const EXTRACT_TIME := 6.0
const INTERACT_RANGE := 36.0
const RAID_TIME_LIMIT := 900.0  # po tym czasie rośnie ryzyko, ale rajd się nie kończy
const CONE_ENERGY := 1.0

var rng := RandomNumberGenerator.new()
var biome: String = "przedmiescia"
var bdef: Dictionary = {}
var tutorial_mode: bool = false
var level: Dictionary
var nav: GridNav
var player: Player
var fx: Node2D
var hud: Label
var inv_ui: InventoryUI
var prompt: Label
var hint_label: Label
var banner: Label
var cam: Camera2D
var map_view: MapView
var modulate_node: CanvasModulate
var cone_light: PointLight2D
var tutorial: Tutorial

var boxes: Array = []
var enemies: Array = []
var faunas: Array = []
var exits: Array = []  # {pos, kind, progress}
var groups: Array = []
var explored: PackedByteArray = PackedByteArray()
var corpse_box: LootBox = null
var corpse_initial: int = 0
var tile_layer: TileLayer
var anomaly_rect := Rect2i(-1, -1, 0, 0)
var in_anomaly: bool = false
var _tutorial_targets: Array = []

var elapsed: float = 0.0
var threat: float = 0.0
var threat_stage: int = 0
var finished: bool = false
var start_value: int = 0
var stats := {"kills": {}, "boxes_opened": 0, "docs": 0, "anomaly": false}
var _end_timer: float = -1.0
var _end_result: String = ""
var _saved_equipment: Equipment = null
var _explore_t: float = 0.0
var _banner_t: float = 0.0
var _last_tick: int = -1
var _flicker_t: float = 0.0


func _ready() -> void:
	rng.randomize()
	var nr: Dictionary = Game.next_raid
	tutorial_mode = nr.get("tutorial", false)
	biome = "szkolenie" if tutorial_mode else nr.get("biome", Game.selected_biome)
	bdef = Biomes.get_def(biome)
	if tutorial_mode:
		_saved_equipment = Game.equipment
		Game.equipment = _training_kit()
	level = LevelGen.new().generate(rng.randi(), biome)
	nav = GridNav.new(level["rows"], TILE)
	explored.resize(nav.size.x * nav.size.y)
	var ar: Vector2i = level["anomaly_room"]
	if ar.x >= 0:
		var rs: Vector2i = level["room_size"]
		anomaly_rect = Rect2i(ar.x * rs.x, ar.y * rs.y, rs.x, rs.y)

	# światło otoczenia: ciemno, widać tylko to, co oświetla latarka/stożek
	modulate_node = CanvasModulate.new()
	modulate_node.color = bdef.get("ambient", Color(0.12, 0.12, 0.15))
	add_child(modulate_node)

	tile_layer = TileLayer.new()
	add_child(tile_layer)
	tile_layer.setup(level["rows"], bdef.get("tiles", "a"), anomaly_rect)
	_build_colliders()
	fx = FxLayer.new()
	fx.z_index = 10

	_spawn_player()
	if tutorial_mode:
		_spawn_tutorial_world()
	else:
		_spawn_loot()
		_spawn_corpse()
		_spawn_enemies()
	add_child(fx)
	player.set_fx_layer(fx)
	_setup_lights()
	_setup_ui()
	if tutorial_mode:
		tutorial = Tutorial.new()
		add_child(tutorial)
		tutorial.setup(self, _tutorial_targets, hint_label)

	Events.noise.connect(_on_noise)
	_prefill_weapons()
	start_value = Game.equipment.total_value()
	if not tutorial_mode:
		Game.raids_done += 1
	Audio.ambient(bdef.get("ambient_sound", "amb_suburb"), -13.0)
	_mark_explored()
	_say(String(bdef.get("name", "")), 4.0)


func _training_kit() -> Equipment:
	var eq := Equipment.new()
	var rifle := Item.new("rifle_skm")
	rifle.loaded = 30
	eq.equip("primary", rifle)
	var pistol := Item.new("pistol_p9")
	pistol.loaded = 12
	eq.equip("pistol", pistol)
	eq.equip("armor", Item.new("armor_3"))
	eq.equip("head", Item.new("helmet_2"))
	eq.equip("rig", Item.new("rig_a"))
	eq.equip("backpack", Item.new("backpack_b"))
	eq.equip("belt", Item.new("belt_a"))
	eq.add_auto(Item.new("ammo_556", 90), true)
	eq.add_auto(Item.new("ammo_9", 24), true)
	eq.add_auto(Item.new("bandage", 1), true)
	return eq


## Załaduj bronie z zapasu amunicji przed wyjściem (magazynki pełne na starcie).
func _prefill_weapons() -> void:
	for slot in ["primary", "pistol"]:
		var w: Item = Game.equipment.get_slot(slot)
		if w == null:
			continue
		var mag: int = w.def()["weapon"]["mag"]
		var need := mag - w.loaded
		if need > 0:
			var got: int = Game.equipment.take("ammo_" + String(w.def()["ammo_type"]), need)[0]
			w.loaded += got
	player.equipment_changed()


func _on_noise(_pos: Vector2, radius: float, source: Node) -> void:
	if source == player and radius >= 100.0:
		threat += 0.7 * radius / 300.0


# --- budowa świata -------------------------------------------------------

func _build_colliders() -> void:
	var rows: Array = level["rows"]
	var body := StaticBody2D.new()
	body.collision_layer = 1
	add_child(body)
	for y in rows.size():
		var row: String = rows[y]
		var x := 0
		while x < row.length():
			if row[x] == "#" or row[x] == "c":
				var x0 := x
				while x < row.length() and (row[x] == "#" or row[x] == "c"):
					x += 1
				var run := x - x0
				var shape := CollisionShape2D.new()
				var rect := RectangleShape2D.new()
				rect.size = Vector2(run * TILE, TILE)
				shape.shape = rect
				shape.position = Vector2(x0 * TILE + run * TILE / 2.0, y * TILE + TILE / 2.0)
				body.add_child(shape)
				var occ := LightOccluder2D.new()
				var poly := OccluderPolygon2D.new()
				var hw := run * TILE / 2.0
				poly.polygon = PackedVector2Array([Vector2(-hw, -16), Vector2(hw, -16), Vector2(hw, 16), Vector2(-hw, 16)])
				occ.occluder = poly
				occ.position = shape.position
				add_child(occ)
			else:
				x += 1


func _spawn_loot() -> void:
	var kinds := [["szafka", 0.34], ["skrzynia", 0.26], ["biurko", 0.3], ["sejf", 0.1]]
	var anomaly_spots: Array = level["anomaly_loot"]
	for p in level["loot"]:
		var is_anomaly := anomaly_spots.has(p)
		if not is_anomaly and rng.randf() > 0.7:
			continue
		var kind := "szafka"
		if is_anomaly:
			kind = "anomalia"
		else:
			var roll := rng.randf()
			var acc := 0.0
			for k in kinds:
				acc += k[1]
				if roll <= acc:
					kind = k[0]
					break
		var b := LootBox.new()
		b.position = p
		add_child(b)
		b.setup(kind, LootTable.roll(kind, rng, biome), false, biome)
		boxes.append(b)


func _spawn_player() -> void:
	player = Player.new()
	player.position = level["start"]
	player.sight_nav = nav
	add_child(player)
	player.setup(Game.equipment)
	player.died.connect(_on_player_died)
	for e in level["exits"]:
		exits.append({"pos": e["pos"], "kind": e["kind"], "progress": 0.0})
	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 12.0
	player.add_child(cam)


## Własne ciało z poprzedniej śmierci w tym samym biomie: leży daleko od startu, rzeczy częściowo rozkradzione.
func _spawn_corpse() -> void:
	var items := Game.take_corpse_items(biome)
	if items.is_empty():
		return
	var cells: Array = level["fauna_cells"]
	if cells.is_empty():
		return
	var pos: Vector2 = cells[rng.randi() % cells.size()]
	var b := LootBox.new()
	b.position = pos
	add_child(b)
	b.title = "Twoje ciało"
	b.setup("Gracz", items, true, biome)
	for it in b.bag.items:
		it.revealed = true
	corpse_box = b
	corpse_initial = b.bag.items.size()
	boxes.append(b)


func _spawn_enemies() -> void:
	for sp in level["spawns"]:
		var g := GroupManager.new()
		g.nav = nav
		add_child(g)
		groups.append(g)
		var idx := 0
		for pos in sp["cells"]:
			var e := Enemy.new()
			e.position = pos
			e.faction = sp["faction"]
			e.elite = sp.get("elite", false) and idx == 0
			add_child(e)
			e.setup(nav, player, fx)
			g.add_member(e)
			e.killed.connect(_on_enemy_killed)
			enemies.append(e)
			idx += 1


func _spawn_tutorial_world() -> void:
	var t: Dictionary = level["tutorial"]
	for p in t["targets"]:
		var tg := Target.new()
		tg.position = p
		add_child(tg)
		_tutorial_targets.append(tg)
	var box := LootBox.new()
	box.position = t["box"]
	add_child(box)
	box.setup("szafka", [Item.new("bandage", 2), Item.new("painkiller", 1), Item.new("document", 1)], false, biome)
	boxes.append(box)
	var g := GroupManager.new()
	g.nav = nav
	add_child(g)
	groups.append(g)
	var e := Enemy.new()
	e.position = t["enemy"]
	e.faction = "Szabrownicy"
	add_child(e)
	e.setup(nav, player, fx)
	g.add_member(e)
	e.killed.connect(_on_enemy_killed)
	enemies.append(e)


func _on_enemy_killed(e: Enemy) -> void:
	var k: Dictionary = stats["kills"]
	k[e.faction] = k.get(e.faction, 0) + 1
	if e.elite:
		k["Elita"] = k.get("Elita", 0) + 1
	var corpse := LootBox.new()
	corpse.position = e.position
	add_child(corpse)
	var kind := "Elita" if e.elite else e.faction
	if e.elite:
		corpse.title = "Ciało (%s)" % bdef.get("elite", "Dowódca")
	corpse.setup(kind, LootTable.roll(kind, rng, biome), true, biome)
	boxes.append(corpse)
	enemies.erase(e)
	e.queue_free()


func _setup_lights() -> void:
	cone_light = PointLight2D.new()
	cone_light.texture = _cone_texture()
	cone_light.texture_scale = Player.SIGHT_RANGE / 128.0
	cone_light.shadow_enabled = true
	cone_light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	cone_light.energy = CONE_ENERGY
	cone_light.color = Color(1.0, 0.95, 0.85)
	player.add_child(cone_light)
	var near := PointLight2D.new()
	near.texture = _circle_texture()
	near.texture_scale = 70.0 / 64.0
	near.shadow_enabled = true
	near.energy = 0.8
	near.color = Color(0.8, 0.85, 1.0)
	player.add_child(near)


func _cone_texture() -> Texture2D:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := Player.FOV_DEG * 0.5
	for y in size:
		for x in size:
			var dx := (x - 127.5) / 127.5
			var dy := (y - 127.5) / 127.5
			var r := sqrt(dx * dx + dy * dy)
			var a := 0.0
			if r < 1.0:
				var ang := absf(rad_to_deg(atan2(dy, dx)))
				var edge := clampf((half - ang) / 8.0, 0.0, 1.0)
				a = edge * (1.0 - r * r)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func _circle_texture() -> Texture2D:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var dx := (x - 63.5) / 63.5
			var dy := (y - 63.5) / 63.5
			var r := sqrt(dx * dx + dy * dy)
			var a := clampf(1.0 - r, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	hud = Label.new()
	hud.set_script(load("res://scripts/hud.gd"))
	hud.position = Vector2(6, 4)
	hud.add_theme_font_size_override("font_size", 8)
	layer.add_child(hud)
	prompt = Label.new()
	prompt.position = Vector2(180, 330)
	prompt.size = Vector2(280, 20)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 9)
	layer.add_child(prompt)
	hint_label = Label.new()
	hint_label.position = Vector2(170, 4)
	hint_label.size = Vector2(300, 40)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 9)
	hint_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	hint_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	hint_label.add_theme_constant_override("shadow_offset_x", 1)
	hint_label.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(hint_label)
	banner = Label.new()
	banner.position = Vector2(120, 300)
	banner.size = Vector2(400, 24)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 10)
	banner.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	banner.add_theme_constant_override("shadow_offset_x", 1)
	banner.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(banner)
	add_child(layer)
	hud.setup(player)
	hud.raid = self
	map_view = MapView.new()
	map_view.raid = self
	var map_layer := CanvasLayer.new()
	map_layer.layer = 8
	map_layer.add_child(map_view)
	add_child(map_layer)
	inv_ui = InventoryUI.new()
	inv_ui.layer = 10
	add_child(inv_ui)
	inv_ui.setup(Game.equipment, player, true)
	inv_ui.closed.connect(func(): player.input_locked = false)


func _say(text: String, secs: float = 3.5) -> void:
	if banner:
		banner.text = text
		_banner_t = secs


# --- pętla ----------------------------------------------------------------

func _process(delta: float) -> void:
	if finished:
		return
	elapsed += delta
	threat += delta * (0.3 + (0.4 if elapsed > RAID_TIME_LIMIT else 0.0))
	_update_threat()
	_update_anomaly(delta)
	if _banner_t > 0.0:
		_banner_t -= delta
		if _banner_t <= 0.0:
			banner.text = ""
	_explore_t -= delta
	if _explore_t <= 0.0:
		_explore_t = 0.25
		_mark_explored()
	if _end_timer >= 0.0:
		_end_timer -= delta
		if _end_timer <= 0.0:
			_finish(_end_result)
		return
	_update_interaction(delta)
	_update_extraction(delta)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if finished or not player.is_alive():
		return
	if event.is_action_pressed("inventory"):
		if inv_ui.visible:
			inv_ui.close()
		else:
			inv_ui.open_player()
			player.input_locked = true
	elif event.is_action_pressed("map"):
		map_view.toggle()


func _mark_explored() -> void:
	var c := nav.to_cell(player.global_position)
	var r := 10
	var w := nav.size.x
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var cell := c + Vector2i(dx, dy)
			if not nav.in_bounds(cell):
				continue
			var idx := cell.y * w + cell.x
			if explored[idx] == 1:
				continue
			var p := nav.center(cell)
			if p.distance_to(player.global_position) > Player.SIGHT_RANGE:
				continue
			if player.can_see_point(p):
				explored[idx] = 1


func _update_anomaly(delta: float) -> void:
	if anomaly_rect.position.x < 0:
		return
	var cell := nav.to_cell(player.global_position)
	var now_in := anomaly_rect.has_point(cell)
	if now_in and not in_anomaly:
		_say("Pomieszczenie powtarza się. Wydaje się znajome.", 4.5)
		stats["anomaly"] = true
	if now_in != in_anomaly:
		in_anomaly = now_in
		Audio.layer("anomaly_whisper" if in_anomaly else "", -14.0)
	var ambient: Color = bdef.get("ambient", Color(0.12, 0.12, 0.15))
	if in_anomaly:
		threat += delta * 1.5
		_flicker_t -= delta
		if _flicker_t <= 0.0:
			_flicker_t = randf_range(0.05, 0.4)
			cone_light.energy = randf_range(0.5, 1.3)
			modulate_node.color = ambient.lerp(Color(0.3, 0.12, 0.35), randf_range(0.0, 0.6))
	else:
		cone_light.energy = CONE_ENERGY
		modulate_node.color = modulate_node.color.lerp(ambient, minf(1.0, delta * 3.0))


func _update_threat() -> void:
	var period: float = bdef.get("fauna_period", 45.0)
	var stage := int(threat / period)
	if stage > threat_stage:
		threat_stage = stage
		_spawn_fauna(1 + stage / 3)
	faunas = faunas.filter(func(f): return is_instance_valid(f) and f.alive)


func _spawn_fauna(n: int) -> void:
	var cells: Array = level["fauna_cells"]
	if cells.is_empty() or faunas.size() >= 6:
		return
	for i in n:
		for tries in 30:
			var p: Vector2 = cells[rng.randi() % cells.size()]
			if p.distance_to(player.global_position) > 260.0 and not player.can_see_point(p):
				var f := Fauna.new()
				f.position = p
				add_child(f)
				f.setup(nav, player)
				f.died_signal.connect(func():
					stats["kills"]["Fauna"] = stats["kills"].get("Fauna", 0) + 1)
				faunas.append(f)
				break


func _update_interaction(delta: float) -> void:
	var best: LootBox = null
	var best_d := INTERACT_RANGE
	for b: LootBox in boxes:
		if not is_instance_valid(b):
			continue
		var d: float = b.global_position.distance_to(player.global_position)
		if d < best_d and nav.has_los(player.global_position, b.global_position):
			best = b
			best_d = d
	prompt.text = ""
	if best and not inv_ui.visible and player.is_alive():
		prompt.text = "E: przeszukaj — %s" % best.display_name()
		if Input.is_action_just_pressed("interact"):
			inv_ui.open_box(best)
			player.input_locked = true
			stats["boxes_opened"] += 1
			Audio.play("loot_open", -5.0)
	if inv_ui.visible and inv_ui.current_box and is_instance_valid(inv_ui.current_box):
		if inv_ui.current_box.global_position.distance_to(player.global_position) > INTERACT_RANGE + 24.0:
			inv_ui.close()
		elif inv_ui.current_box.reveal_step(delta):
			Audio.play("loot_reveal", -8.0)
			inv_ui.refresh()


func _update_extraction(delta: float) -> void:
	if not player.is_alive():
		return
	var msg := ""
	for e in exits:
		var near: bool = player.global_position.distance_to(e["pos"]) < 44.0
		if near:
			if e["kind"] == "key" and Game.equipment.count_of("key_exit") <= 0:
				msg = "Brama zamknięta. Potrzebny klucz do bramy kordonu."
				e["progress"] = 0.0
			else:
				e["progress"] += delta
				msg = "Ewakuacja: %.0f%%" % (100.0 * e["progress"] / EXTRACT_TIME)
				var sec := int(e["progress"])
				if sec != _last_tick:
					_last_tick = sec
					Audio.play("extract_tick", -6.0, 1.0 + 0.04 * sec, 0.0)
				if e["progress"] >= EXTRACT_TIME:
					if e["kind"] == "key":
						Game.equipment.take("key_exit", 1)
					Audio.play("extract_done", -2.0, 1.0, 0.0)
					_end_result = "extracted"
					_finish("extracted")
					return
		else:
			e["progress"] = maxf(0.0, e["progress"] - delta * 2.0)
	if msg != "":
		prompt.text = msg
	else:
		_last_tick = -1


func _on_player_died(_cause: String) -> void:
	_end_result = "dead"
	_end_timer = 2.5
	if inv_ui.visible:
		inv_ui.close()


func _finish(result: String) -> void:
	if finished:
		return
	finished = true
	player.writeback_armor()
	Audio.stop_all()
	if tutorial_mode:
		_finish_tutorial(result)
		return
	# stan ciała z poprzedniej śmierci (to, co gracz zostawił)
	if corpse_box and is_instance_valid(corpse_box):
		Game.store_corpse_remaining(biome, corpse_box.bag.items)
	var end_value := Game.equipment.total_value()
	var report := {
		"result": result, "time": elapsed, "kills": stats["kills"].duplicate(), "biome": biome,
		"cause": player.body.cause_of_death, "last_source": player.last_hit_source,
		"start_value": start_value, "end_value": end_value,
		"arms_hurt": player.body.frac(Body.Part.ARMS) < 0.5, "boxes": stats["boxes_opened"],
		"threat": int(threat), "anomaly": stats["anomaly"],
	}
	if corpse_box:
		report["corpse_found"] = true
		report["corpse_taken"] = corpse_initial - (corpse_box.bag.items.size() if is_instance_valid(corpse_box) else 0)
	if result == "dead":
		Game.deaths += 1
		var d := Game.process_death(Game.equipment, biome)
		for k in d:
			report[k] = d[k]
		report["end_value"] = Game.equipment.total_value()
	else:
		Game.extractions += 1
	var info := Game.register_raid(report, biome)
	report["unlocked"] = info["unlocked"]
	Game.pending_report = report
	Game.last_report = report.duplicate(true)
	Game.save_game()
	get_tree().change_scene_to_file("res://scenes/base.tscn")


func _finish_tutorial(result: String) -> void:
	Game.equipment = _saved_equipment
	var ok := result == "extracted"
	if ok:
		Game.tutorial_done = true
		Game.last_ctx = "first"
	Game.pending_report = {"result": "tutorial_ok" if ok else "tutorial_fail", "time": elapsed, "cause": player.body.cause_of_death}
	Game.last_report = Game.pending_report.duplicate(true)
	Game.next_raid = {}
	Game.save_game()
	get_tree().change_scene_to_file("res://scenes/base.tscn")


# --- rysowanie (tylko strefy wyjścia; kafelki są w TileLayer) -----------------

func _draw() -> void:
	var frame := Assets.tex("exit_frame")
	for e in exits:
		var col := Color(0.2, 0.8, 0.4) if e["kind"] == "open" else Color(0.9, 0.75, 0.2)
		var r := Rect2(e["pos"] - Vector2(TILE, TILE), Vector2(TILE * 2, TILE * 2))
		draw_rect(r, Color(col.r, col.g, col.b, 0.22))
		if frame:
			draw_texture_rect(frame, r, false, col)
		else:
			draw_rect(r, col, false, 2.0)
		if e["progress"] > 0.0:
			var frac: float = e["progress"] / EXTRACT_TIME
			draw_rect(Rect2(e["pos"] + Vector2(-TILE, TILE + 4), Vector2(TILE * 2 * frac, 4)), col)
