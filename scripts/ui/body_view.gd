class_name BodyView
extends Control
## Ludzik ze stanem 7 części ciała (jak w Tarkovie): kolor = HP, krople = krwawienie,
## zygzak = złamanie, czarny z krzyżykiem = zniszczona kończyna. Używany w HUD (mały) i ekwipunku (klikalny).

signal part_input(part: int, event: InputEventMouseButton)
signal part_hovered(part: int)

const BASE_SIZE := Vector2(40, 78)
const LIST_WIDTH := 64.0

## Prostokąty części w jednostkach bazowych.
const RECTS := {
	Body.Part.HEAD: Rect2(14, 1, 12, 12),
	Body.Part.CHEST: Rect2(12, 15, 16, 16),
	Body.Part.STOMACH: Rect2(13, 32, 14, 11),
	Body.Part.L_ARM: Rect2(3, 16, 8, 26),
	Body.Part.R_ARM: Rect2(29, 16, 8, 26),
	Body.Part.L_LEG: Rect2(12, 45, 8, 32),
	Body.Part.R_LEG: Rect2(21, 45, 8, 32),
}

var body: Body
var player: Player
var view_scale: float = 1.0
var interactive: bool = false
var show_list: bool = false
var hint_kind: String = ""  # podświetla części, które potrzebują tego środka (np. "bandage")
var _hover: int = -1
var _t: float = 0.0


func setup(p_body: Body, p_scale: float, p_interactive: bool, p_list: bool, p_player: Player = null) -> void:
	body = p_body
	view_scale = p_scale
	interactive = p_interactive
	show_list = p_list
	player = p_player
	custom_minimum_size = BASE_SIZE * p_scale + Vector2(LIST_WIDTH if p_list else 0.0, 0.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP if p_interactive else Control.MOUSE_FILTER_IGNORE


func part_at(local: Vector2) -> int:
	for p in RECTS:
		var r: Rect2 = RECTS[p]
		var rr := Rect2(r.position * view_scale - Vector2(1, 1), r.size * view_scale + Vector2(2, 2))
		if rr.has_point(local):
			return p
	return -1


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseMotion:
		var p := part_at(event.position)
		if p != _hover:
			_hover = p
			part_hovered.emit(p)
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		var p2 := part_at(event.position)
		if p2 >= 0:
			part_input.emit(p2, event)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != -1:
		_hover = -1
		part_hovered.emit(-1)
		queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


static func part_color(frac: float, dead_part: bool) -> Color:
	if dead_part:
		return Color(0.16, 0.16, 0.18)
	if frac > 0.66:
		return Color(0.42, 0.78, 0.4)
	if frac > 0.33:
		return Color(0.92, 0.74, 0.28)
	return Color(0.9, 0.32, 0.25)


func _draw() -> void:
	if body == null:
		return
	var font := ThemeDB.fallback_font
	for p in Body.PARTS:
		var r: Rect2 = RECTS[p]
		var rr := Rect2(r.position * view_scale, r.size * view_scale)
		var hp: float = body.hp[p]
		var frac: float = hp / maxf(1.0, body.max_hp[p])
		var dead_part: bool = hp <= 0.0
		var col := part_color(frac, dead_part)
		if not body.alive:
			col = col.darkened(0.4)
		draw_rect(rr, col)
		var outline := Color(0.05, 0.06, 0.07)
		if hint_kind != "" and body.needs(hint_kind, p):
			var pulse := 0.5 + 0.5 * sin(_t * 8.0)
			outline = Color(0.5 + 0.5 * pulse, 1.0, 0.6)
			draw_rect(rr.grow(1.0), outline, false, 1.5)
		elif p == _hover:
			draw_rect(rr.grow(1.0), Color(1, 1, 1), false, 1.5)
		else:
			draw_rect(rr, outline, false, 1.0)
		# zniszczona kończyna: krzyżyk
		if dead_part and p != Body.Part.HEAD and p != Body.Part.CHEST:
			draw_line(rr.position + Vector2(1, 1), rr.end - Vector2(1, 1), Color(0.8, 0.15, 0.15), 1.5)
			draw_line(Vector2(rr.end.x - 1, rr.position.y + 1), Vector2(rr.position.x + 1, rr.end.y - 1), Color(0.8, 0.15, 0.15), 1.5)
		# krwawienie: krople w rogu (ciężkie pulsują)
		var b: int = body.bleed[p]
		if b > 0:
			var c := rr.position + Vector2(rr.size.x - 1.5, 2.0)
			var rad := (1.7 if b == 1 else 2.6) * maxf(0.8, view_scale * 0.8)
			if b == 2:
				rad *= 0.85 + 0.15 * sin(_t * 9.0)
			draw_circle(c, rad, Color(0.85, 0.05, 0.08))
			draw_circle(c, rad * 0.45, Color(1.0, 0.5, 0.5))
		# złamanie: biały zygzak
		if body.fracture[p] and not dead_part:
			var cx := rr.position.x + rr.size.x / 2.0
			var y0 := rr.position.y + rr.size.y * 0.3
			var s := maxf(1.0, view_scale)
			draw_polyline(PackedVector2Array([Vector2(cx - 2 * s, y0), Vector2(cx + 1.5 * s, y0 + 2 * s),
				Vector2(cx - 1.5 * s, y0 + 4 * s), Vector2(cx + 2 * s, y0 + 6 * s)]), Color(1, 1, 1), 1.3)
		# postęp zabiegu na tej części
		if player and player.using_item != "" and player.using_part == p:
			var prog := player.use_progress()
			draw_rect(Rect2(rr.position.x, rr.end.y - 3.0, rr.size.x * prog, 3.0), Color(0.5, 0.9, 1.0))
	# tabletki przeciwbólowe aktywne
	if body.painkilled():
		draw_circle(Vector2(BASE_SIZE.x * view_scale - 3, BASE_SIZE.y * view_scale - 3), 2.5, Color(0.35, 0.65, 0.95))
	if show_list:
		var x := BASE_SIZE.x * view_scale + 6.0
		var y := 8.0
		for p in Body.PARTS:
			var hp2: float = body.hp[p]
			var mx: float = body.max_hp[p]
			var col2 := part_color(hp2 / maxf(1.0, mx), hp2 <= 0.0)
			if hp2 <= 0.0:
				col2 = Color(0.75, 0.35, 0.35)
			var nm: String = Body.PART_NAMES[p]
			draw_string(font, Vector2(x, y), "%s %d/%d" % [nm.substr(0, 9), int(ceil(hp2)), int(mx)],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 6, col2)
			y += 9.0
		y += 2.0
		if body.pain > 0.3:
			draw_string(font, Vector2(x, y), "Ból", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(1, 0.7, 0.4))
