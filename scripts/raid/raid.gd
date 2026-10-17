extends Node2D
## Rajd: losowy układ pokoi, światło i stożek widzenia, wrogowie, łup, ewakuacja, raport.

const TILE := 32
const EXTRACT_TIME := 6.0
const INTERACT_RANGE := 36.0
const RAID_TIME_LIMIT := 900.0  # po tym czasie rośnie ryzyko, ale rajd się nie kończy

var rng := RandomNumberGenerator.new()
var level: Dictionary
var nav: GridNav
var player: Player
var fx: Node2D
var hud: Label
var inv_ui: InventoryUI
var prompt: Label
var cam: Camera2D

var boxes: Array = []
var enemies: Array = []
var faunas: Array = []
var exits: Array = []  # {pos, kind, progress}
var groups: Array = []

var elapsed: float = 0.0
var threat: float = 0.0
var threat_stage: int = 0
var finished: bool = false
var start_value: int = 0
var stats := {"kills": {}, "boxes_opened": 0, "docs": 0}
var _end_timer: float = -1.0
var _end_result: String = ""


func _ready() -> void:
	rng.randomize()
	var seed_value := rng.randi()
	level = LevelGen.new().generate(seed_value)
	nav = GridNav.new(level["rows"], TILE)

	# światło otoczenia: ciemno, widać tylko to, co oświetla latarka/stożek
	var mod := CanvasModulate.new()
	mod.color = Color(0.17, 0.17, 0.21)
	add_child(mod)

	_build_colliders()
	fx = Node2D.new()
	fx.set_script(load("res://scripts/fx_layer.gd"))
	fx.z_index = 10

	_spawn_loot()
	_spawn_player()
	_spawn_enemies()
	add_child(fx)
	player.set_fx_layer(fx)
	_setup_lights()
	_setup_ui()

	Events.noise.connect(_on_noise)
	_prefill_weapons()
	start_value = Game.equipment.total_value()
	Game.raids_done += 1


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


func _on_noise(_pos: Vector2, _radius: float, source: Node) -> void:
	if source == player:
		threat += 0.7


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
	for p in level["loot"]:
		if rng.randf() > 0.7:
			continue
		var roll := rng.randf()
		var kind := "szafka"
		var acc := 0.0
		for k in kinds:
			acc += k[1]
			if roll <= acc:
				kind = k[0]
				break
		var b := LootBox.new()
		b.position = p
		add_child(b)
		b.setup(kind, LootTable.roll(kind, rng))
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


func _spawn_enemies() -> void:
	for sp in level["spawns"]:
		var g := GroupManager.new()
		g.nav = nav
		add_child(g)
		groups.append(g)
		for pos in sp["cells"]:
			var e := Enemy.new()
			e.position = pos
			e.faction = sp["faction"]
			add_child(e)
			e.setup(nav, player, fx)
			g.add_member(e)
			e.killed.connect(_on_enemy_killed)
			enemies.append(e)


func _on_enemy_killed(e: Enemy) -> void:
	var k: Dictionary = stats["kills"]
	k[e.faction] = k.get(e.faction, 0) + 1
	var corpse := LootBox.new()
	corpse.position = e.position
	add_child(corpse)
	corpse.setup(e.faction, LootTable.roll(e.faction, rng), true)
	boxes.append(corpse)
	enemies.erase(e)
	e.queue_free()


func _setup_lights() -> void:
	var cone := PointLight2D.new()
	cone.texture = _cone_texture()
	cone.texture_scale = Player.SIGHT_RANGE / 128.0
	cone.shadow_enabled = true
	cone.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	cone.energy = 1.25
	cone.color = Color(1.0, 0.95, 0.85)
	player.add_child(cone)
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
	prompt.position = Vector2(220, 330)
	prompt.add_theme_font_size_override("font_size", 9)
	layer.add_child(prompt)
	add_child(layer)
	hud.setup(player)
	hud.raid = self
	inv_ui = InventoryUI.new()
	inv_ui.layer = 10
	add_child(inv_ui)
	inv_ui.setup(Game.equipment, player, true)
	inv_ui.closed.connect(func(): player.input_locked = false)


# --- pętla ----------------------------------------------------------------

func _process(delta: float) -> void:
	if finished:
		return
	elapsed += delta
	threat += delta * (0.3 + (0.4 if elapsed > RAID_TIME_LIMIT else 0.0))
	_update_threat()
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


func _update_threat() -> void:
	var stage := int(threat / 45.0)
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
	if inv_ui.visible and inv_ui.current_box and is_instance_valid(inv_ui.current_box):
		if inv_ui.current_box.global_position.distance_to(player.global_position) > INTERACT_RANGE + 24.0:
			inv_ui.close()
		elif inv_ui.current_box.reveal_step(delta):
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
				if e["progress"] >= EXTRACT_TIME:
					if e["kind"] == "key":
						Game.equipment.take("key_exit", 1)
					_end_result = "extracted"
					_finish("extracted")
					return
		else:
			e["progress"] = maxf(0.0, e["progress"] - delta * 2.0)
	if msg != "":
		prompt.text = msg


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
	var end_value := Game.equipment.total_value()
	var report := {
		"result": result, "time": elapsed, "kills": stats["kills"].duplicate(),
		"cause": player.body.cause_of_death, "last_source": player.last_hit_source,
		"start_value": start_value, "end_value": end_value,
		"arms_hurt": player.body.frac(Body.Part.ARMS) < 0.5, "boxes": stats["boxes_opened"],
		"threat": int(threat),
	}
	if result == "dead":
		Game.deaths += 1
		Game.equipment.lose_all_but_secure()
		report["end_value"] = Game.equipment.total_value()
	else:
		Game.extractions += 1
	Game.pending_report = report
	Game.save_game()
	get_tree().change_scene_to_file("res://scenes/base.tscn")


# --- rysowanie ------------------------------------------------------------

func _draw() -> void:
	var rows: Array = level["rows"]
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch == " ":
				continue
			var r := Rect2(x * TILE, y * TILE, TILE, TILE)
			match ch:
				"#":
					draw_rect(r, Color(0.3, 0.32, 0.36))
					draw_rect(r, Color(0.2, 0.22, 0.25), false, 1.0)
				"c":
					draw_rect(r, Color(0.5, 0.43, 0.3))
					draw_rect(Rect2(r.position + Vector2(4, 4), r.size - Vector2(8, 8)), Color(0.42, 0.36, 0.25))
				_:
					var shade := 0.38 + 0.03 * float((x + y) % 2)
					draw_rect(r, Color(shade, shade * 0.97, shade * 0.9))
	for e in exits:
		var col := Color(0.2, 0.8, 0.4) if e["kind"] == "open" else Color(0.9, 0.75, 0.2)
		draw_rect(Rect2(e["pos"] - Vector2(TILE, TILE), Vector2(TILE * 2, TILE * 2)), Color(col.r, col.g, col.b, 0.3))
		draw_rect(Rect2(e["pos"] - Vector2(TILE, TILE), Vector2(TILE * 2, TILE * 2)), col, false, 2.0)
		if e["progress"] > 0.0:
			var frac: float = e["progress"] / EXTRACT_TIME
			draw_rect(Rect2(e["pos"] + Vector2(-TILE, TILE + 4), Vector2(TILE * 2 * frac, 4)), col)
