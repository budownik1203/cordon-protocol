extends Control
## HUD: tylko niezbędne rzeczy. Ikonka stanu obrażeń (lewy dolny róg), pasek szybkiego dostępu (środek)
## i broń z amunicją (prawy dolny róg). Reszta (zdrowie szczegółowo, waga) jest w ekwipunku.

const SLOT := 22.0
const GAP := 2.0

var _player: Player
var raid: Node = null
var _icon: BodyView


func _init() -> void:
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(player: Player) -> void:
	_player = player
	_icon = BodyView.new()
	_icon.setup(player.body, 0.8, false, false, player)
	_icon.position = Vector2(6, 360.0 - 6.0 - BodyView.BASE_SIZE.y * 0.8)
	add_child(_icon)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _player == null:
		return
	var font := ThemeDB.fallback_font
	var eq := _player.equipment
	# --- pasek szybkiego dostępu ---
	var total_w := Game.HOTBAR_SIZE * (SLOT + GAP) - GAP
	var x0 := (640.0 - total_w) / 2.0
	var y0 := 360.0 - 6.0 - SLOT
	for i in Game.HOTBAR_SIZE:
		var r := Rect2(x0 + i * (SLOT + GAP), y0, SLOT, SLOT)
		draw_rect(r, Color(0.05, 0.06, 0.07, 0.75))
		var id: String = Game.hotbar[i]
		var active := id != "" and _player.using_item == id
		draw_rect(r, Color(0.5, 0.9, 1.0) if active else Color(0.3, 0.33, 0.38, 0.9), false, 1.0)
		draw_string(font, r.position + Vector2(2, 7), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0.7, 0.75, 0.8))
		if id == "":
			continue
		var d := ItemDB.get_def(id)
		var n := eq.count_of(id)
		var c: Color = d.get("color", Color(0.6, 0.6, 0.6))
		if n <= 0:
			c = c.darkened(0.7)
		var ir := Rect2(r.position + Vector2(4, 7), Vector2(SLOT - 8, SLOT - 10))
		draw_rect(ir, c.darkened(0.2))
		draw_rect(ir, c.lightened(0.15), false, 1.0)
		var nm: String = String(d.get("name", id)).substr(0, 3)
		draw_string(font, ir.position + Vector2(1, 8), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 6,
			Color(1, 1, 1) if n > 0 else Color(0.5, 0.5, 0.5))
		var count_txt := str(n)
		if id == "medkit":
			var f := eq.find_item(id)
			count_txt = str(int(f["item"].durability)) if not f.is_empty() else "0"
		draw_string(font, r.position + Vector2(SLOT - 3 - 3.2 * count_txt.length(), SLOT - 2), count_txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(1, 0.95, 0.6) if n > 0 else Color(0.6, 0.4, 0.4))
	# --- pasek postępu zabiegu / przeładowania / pakowania ---
	var prog := -1.0
	var label := ""
	if _player.using_item != "":
		prog = _player.use_progress()
		label = "zabieg"
		if _player.using_part >= 0:
			label = "zabieg: %s" % Body.PART_NAMES[_player.using_part]
	elif _player.reloading and _player.reload_kind == "swap":
		prog = 1.0 - _player._reload_left / maxf(0.01, _player._reload_total)
		label = "magazynek"
	elif _player.reloading:
		label = "dobijanie naboi"
	elif _player.loading_mags:
		label = "pakowanie magazynków"
	if label != "":
		var w := 90.0
		var br := Rect2((640.0 - w) / 2.0, y0 - 12.0, w, 4.0)
		draw_rect(br, Color(0, 0, 0, 0.7))
		if prog >= 0.0:
			draw_rect(Rect2(br.position, Vector2(w * clampf(prog, 0.0, 1.0), 4.0)), Color(0.5, 0.9, 1.0))
		draw_string(font, Vector2(br.position.x, br.position.y - 2.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.85, 0.9, 0.95))
	# --- broń i amunicja ---
	if _player.weapon:
		var wi: Item = _player.weapon_item
		var cur := str(_player.ammo) if wi.mag != null else "--"
		var rx := 640.0 - 8.0
		draw_string(font, Vector2(rx - 70, 360.0 - 22.0), _player.weapon.display_name, HORIZONTAL_ALIGNMENT_RIGHT, 70, 7, Color(0.7, 0.75, 0.8))
		var warn := _player.ammo <= 0 or wi.mag == null
		draw_string(font, Vector2(rx - 70, 360.0 - 10.0), cur, HORIZONTAL_ALIGNMENT_RIGHT, 40, 14,
			Color(1.0, 0.4, 0.35) if warn else Color(1, 0.95, 0.7))
		var spare := "+%d" % _player.spare_rounds()
		draw_string(font, Vector2(rx - 28, 360.0 - 10.0), "%s |%d" % [spare, _player.loose_ammo()],
			HORIZONTAL_ALIGNMENT_RIGHT, 28, 7, Color(0.75, 0.8, 0.85))
	if not _player.is_alive():
		draw_string(font, Vector2(0, 150), "NIE ŻYJESZ: %s" % _player.body.cause_of_death,
			HORIZONTAL_ALIGNMENT_CENTER, 640, 12, Color(1, 0.4, 0.4))
