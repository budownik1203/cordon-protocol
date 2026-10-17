extends Node3D
## Próbna wersja 3D low poly: ten sam generator poziomów i model obrażeń, widok z góry pod kątem.
## Sterowanie: WASD ruch, mysz celowanie, LPM strzał, R przeładowanie, Shift sprint, C kuc, E skrzynia, Esc baza.

const CAM_OFFSET := Vector3(0, 13.0, 7.5)

var level: Dictionary = {}
var level3d: Level3D
var player: Player3D
var cam: Camera3D
var enemies: Array = []
var crates: Array = []
var nav: GridNav
var biome: String = "przedmiescia"
var seed_value: int = 0
var hud_ammo: Label
var hud_msg: Label
var hud_help: Label
var body_view: BodyView
var _msg_t: float = 0.0
var _extract_t: float = 0.0
var _ended: bool = false
var _cam_pos := Vector3.ZERO
var _banner: Label
var fps: bool = false
var crosshair: Control


func _ready() -> void:
	var game := get_node_or_null("/root/Game")
	if game != null:
		biome = String(game.next_raid.get("biome", "przedmiescia")) if game.next_raid.has("biome") else "przedmiescia"
		if biome == "szkolenie":
			biome = "przedmiescia"
	var args := OS.get_cmdline_user_args()
	seed_value = randi() if args.is_empty() else int(args[0])
	if args.size() > 1:
		biome = args[1]
	level = LevelGen.new().generate(seed_value, biome)
	nav = GridNav.new(level["rows"], 32)
	_build_world()
	_build_hud()
	_say("Próba 3D: %s" % Biomes.get_def(biome).get("name", biome), 4.0)


func _build_world() -> void:
	level3d = Level3D.new()
	add_child(level3d)
	level3d.build(level["rows"], biome)
	# środowisko: ciemno, mgła, delikatne rozświetlenie
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.01, 0.015)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.4, 0.5) if biome != "kompleks" else Color(0.3, 0.42, 0.5)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.035, 0.05)
	env.fog_density = 0.008
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# gracz
	player = Player3D.new()
	player.fps = fps
	add_child(player)
	var sp: Vector2 = level["start"]
	player.global_position = Vector3(sp.x / 32.0, 0, sp.y / 32.0)
	cam = Camera3D.new()
	cam.far = 120.0
	if fps:
		cam.fov = 78.0
		cam.near = 0.05
		player.cam = cam
		player.setup_fps_camera(cam)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		cam.fov = 38.0
		cam.near = 1.0
		add_child(cam)
		player.cam = cam
		_cam_pos = player.global_position + CAM_OFFSET
		cam.global_position = _cam_pos
		cam.look_at(player.global_position, Vector3.UP)
	player.shot.connect(_on_player_shot)
	player.died.connect(_on_player_died)
	# strefy ewakuacji
	for e in level["exits"]:
		var ep: Vector2 = e["pos"]
		var pad := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 1.3
		bm.bottom_radius = 1.3
		bm.height = 0.06
		pad.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.2, 0.9, 0.4)
		m.emission_enabled = true
		m.emission = Color(0.1, 0.8, 0.3)
		m.emission_energy_multiplier = 1.5
		pad.material_override = m
		pad.position = Vector3(ep.x / 32.0, 0.04, ep.y / 32.0)
		add_child(pad)
		var l := OmniLight3D.new()
		l.light_color = Color(0.3, 1.0, 0.5)
		l.omni_range = 5.0
		l.light_energy = 1.2
		l.position = pad.position + Vector3(0, 1.0, 0)
		add_child(l)
	# skrzynie z łupem
	var n := 0
	for lp in level["loot"]:
		if n >= 26:
			break
		n += 1
		_add_crate(Vector3(lp.x / 32.0, 0, lp.y / 32.0))
	# wrogowie
	var count := 0
	for s in level["spawns"]:
		var faction := String(s["faction"]).to_lower()
		if not Enemy3D.FACTIONS.has(faction):
			faction = "szabrownicy"
		var cells: Array = s["cells"]
		var per := mini(cells.size(), 2)
		for i in per:
			if count >= 16:
				break
			var e3 := Enemy3D.new()
			e3.setup(faction, player, nav)
			add_child(e3)
			var cp: Vector2 = cells[i]
			e3.global_position = Vector3(cp.x / 32.0, 0, cp.y / 32.0)
			enemies.append(e3)
			count += 1


func _add_crate(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.9, 0.5, 0.6)
	base.mesh = bm
	base.material_override = LowPolyFigure._mat(Color(0.42, 0.3, 0.18))
	base.position.y = 0.25
	root.add_child(base)
	var lid := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.96, 0.1, 0.66)
	lid.mesh = lm
	lid.material_override = LowPolyFigure._mat(Color(0.52, 0.38, 0.22))
	lid.position = Vector3(0, 0.55, 0)
	root.add_child(lid)
	var band := MeshInstance3D.new()
	var bm2 := BoxMesh.new()
	bm2.size = Vector3(0.12, 0.54, 0.64)
	band.mesh = bm2
	band.material_override = LowPolyFigure._mat(Color(0.25, 0.25, 0.28), 0.5)
	band.position = Vector3(0, 0.27, 0)
	root.add_child(band)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.8, 0.4)
	l.omni_range = 2.8
	l.light_energy = 0.5
	l.position = Vector3(0, 0.9, 0)
	root.add_child(l)
	crates.append({"node": root, "lid": lid, "open": false, "light": l})


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	body_view = BodyView.new()
	body_view.setup(player.body, 0.8, false, false, null)
	body_view.position = Vector2(6, 360.0 - 6.0 - BodyView.BASE_SIZE.y * 0.8)
	var root := Control.new()
	root.size = Vector2(640, 360)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	root.add_child(body_view)
	hud_ammo = Label.new()
	hud_ammo.position = Vector2(560, 330)
	hud_ammo.size = Vector2(74, 24)
	hud_ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_ammo.add_theme_font_size_override("font_size", 14)
	root.add_child(hud_ammo)
	hud_msg = Label.new()
	hud_msg.position = Vector2(0, 300)
	hud_msg.size = Vector2(640, 14)
	hud_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_msg.add_theme_font_size_override("font_size", 9)
	root.add_child(hud_msg)
	hud_help = Label.new()
	hud_help.position = Vector2(6, 4)
	hud_help.add_theme_font_size_override("font_size", 7)
	hud_help.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8, 0.7))
	hud_help.text = "PRÓBA 3D  |  WASD ruch  mysz celowanie  LPM strzał  R przeładuj  Shift sprint  C kuc  E skrzynia  Esc baza"
	if fps:
		hud_help.text = "PRÓBA FPS  |  WASD ruch  mysz rozglądanie  LPM strzał  PPM przycelowanie  R przeładuj  Shift sprint  C kuc  E skrzynia  Esc baza"
		crosshair = Control.new()
		crosshair.size = Vector2(640, 360)
		crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crosshair.draw.connect(func():
			var c := Vector2(320, 180)
			var spread := player.crosshair_spread() * 60.0
			var col := Color(1, 1, 1, 0.85)
			for dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				crosshair.draw_line(c + dir * (2.0 + spread), c + dir * (5.0 + spread), col, 1.0)
			crosshair.draw_circle(c, 0.6, col))
		root.add_child(crosshair)
	root.add_child(hud_help)
	_banner = Label.new()
	_banner.position = Vector2(0, 140)
	_banner.size = Vector2(640, 40)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 16)
	root.add_child(_banner)


func _say(t: String, secs: float = 3.0) -> void:
	hud_msg.text = t
	_msg_t = secs


func _on_player_shot(pos: Vector3) -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.hear(pos, 28.0)


func _on_player_died(cause: String) -> void:
	_banner.text = "NIE ŻYJESZ: %s\nEnter: od nowa   Esc: baza" % cause
	_ended = true


func _process(delta: float) -> void:
	if _msg_t > 0.0:
		_msg_t -= delta
		if _msg_t <= 0.0:
			hud_msg.text = ""
	if crosshair:
		crosshair.queue_redraw()
	hud_ammo.text = "%d | %d%s" % [player.ammo, player.reserve, " ..." if player.reloading else ""]
	hud_ammo.add_theme_color_override("font_color", Color(1, 0.4, 0.35) if player.ammo == 0 else Color(1, 0.95, 0.7))
	if fps:
		_process_common(delta)
		return
	# kamera podąża miękko, z lekkim kołysaniem
	var target := player.global_position + CAM_OFFSET
	var spd := Vector2(player.velocity.x, player.velocity.z).length()
	_cam_pos = _cam_pos.lerp(target, 1.0 - exp(-delta * 7.0))
	var bob := Vector3(0, absf(sin(Time.get_ticks_msec() / 1000.0 * 5.5)) * 0.04 * spd / 3.0, 0)
	cam.global_position = _cam_pos + bob
	cam.look_at(_cam_pos - CAM_OFFSET + Vector3(0, 0.6, 0), Vector3.UP)
	_process_common(delta)


func _process_common(delta: float) -> void:
	# skrzynie: E otwiera najbliższą
	if Input.is_key_pressed(KEY_E) and not _ended:
		_try_open_crate()
	# ewakuacja
	var in_exit := false
	for e in level["exits"]:
		var ep: Vector2 = e["pos"]
		if Vector2(player.global_position.x, player.global_position.z).distance_to(ep / 32.0) < 1.4:
			in_exit = true
	if in_exit and player.is_alive() and not _ended:
		_extract_t += delta
		_say("Ewakuacja... %d" % int(ceil(4.0 - _extract_t)), 0.3)
		if _extract_t >= 4.0:
			_ended = true
			_banner.text = "EWAKUACJA UDANA\nEnter: od nowa   Esc: baza"
	else:
		_extract_t = 0.0


func _try_open_crate() -> void:
	var best: Dictionary = {}
	var bd := 2.2
	for c in crates:
		if c["open"]:
			continue
		var d: float = (c["node"] as Node3D).global_position.distance_to(player.global_position)
		if d < bd:
			bd = d
			best = c
	if best.is_empty():
		return
	best["open"] = true
	var tw := (best["lid"] as Node3D).create_tween()
	tw.tween_property(best["lid"], "rotation:x", -1.2, 0.25)
	tw.parallel().tween_property(best["lid"], "position:y", 0.8, 0.25)
	(best["light"] as OmniLight3D).light_energy = 1.4
	var ids := ["ammo_556", "bandage", "watch", "mag_556_30", "medkit", "radio", "sample", "document"]
	var id: String = ids[randi() % ids.size()]
	_say("Znaleziono: %s" % ItemDB.get_def(id).get("name", id), 2.5)
	Audio.play("loot_open", -4.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().change_scene_to_file("res://scenes/base.tscn")
		elif event.physical_keycode == KEY_ENTER and _ended:
			get_tree().reload_current_scene()
	if fps and event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
