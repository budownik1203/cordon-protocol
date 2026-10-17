class_name MapView
extends Control
## Mapa rajdu (klawisz M): pokazuje tylko to, co operator już widział. Znaczniki: gracz, wyjścia (po zobaczeniu), ciało.

var raid: Node = null
var _t := 0.0


func _ready() -> void:
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func toggle() -> void:
	visible = not visible
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _t > 0.15:
		_t = 0.0
		queue_redraw()


func _draw() -> void:
	if raid == null or raid.nav == null:
		return
	var sz: Vector2i = raid.nav.size
	var s: float = minf(610.0 / sz.x, 310.0 / sz.y)
	var origin := Vector2((640.0 - sz.x * s) * 0.5, 22.0 + (310.0 - sz.y * s) * 0.5)
	draw_rect(Rect2(0, 0, 640, 360), Color(0.02, 0.03, 0.04, 0.9))
	draw_string(ThemeDB.fallback_font, Vector2(8, 14), "MAPA — %s  (M: zamknij)" % raid.bdef.get("name", ""),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.8, 0.85, 0.9))
	var rows: Array = raid.level["rows"]
	var ex: PackedByteArray = raid.explored
	for y in sz.y:
		var row: String = rows[y]
		for x in sz.x:
			if ex[y * sz.x + x] == 0:
				continue
			var ch := row[x]
			var col := Color(0.32, 0.34, 0.38)
			if ch == "#":
				col = Color(0.16, 0.17, 0.2)
			elif ch == "c":
				col = Color(0.4, 0.34, 0.24)
			elif ch == "X":
				col = Color(0.2, 0.5, 0.3)
			draw_rect(Rect2(origin + Vector2(x, y) * s, Vector2(s + 0.5, s + 0.5)), col)
	for e in raid.exits:
		var c: Vector2i = raid.nav.to_cell(e["pos"])
		if ex[c.y * sz.x + c.x] == 1:
			var col2 := Color(0.3, 0.9, 0.5) if e["kind"] == "open" else Color(0.95, 0.8, 0.25)
			draw_rect(Rect2(origin + Vector2(c) * s - Vector2(s, s), Vector2(s * 3, s * 3)), col2, false, 1.5)
			draw_string(ThemeDB.fallback_font, origin + Vector2(c) * s + Vector2(-8, -4 * s - 2),
				"WYJŚCIE" if e["kind"] == "open" else "BRAMA (klucz)", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, col2)
	if raid.corpse_box and is_instance_valid(raid.corpse_box):
		var cp: Vector2 = origin + raid.corpse_box.global_position / float(raid.TILE) * s
		draw_line(cp - Vector2(4, 4), cp + Vector2(4, 4), Color(1, 0.3, 0.3), 2.0)
		draw_line(cp - Vector2(4, -4), cp + Vector2(4, -4), Color(1, 0.3, 0.3), 2.0)
		draw_string(ThemeDB.fallback_font, cp + Vector2(6, 3), "Twoje ciało", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 0.5, 0.5))
	if raid.player:
		var pp: Vector2 = origin + raid.player.global_position / float(raid.TILE) * s
		var a: float = raid.player.rotation
		var pts := PackedVector2Array([pp + Vector2.from_angle(a) * 5.0, pp + Vector2.from_angle(a + 2.5) * 4.0, pp + Vector2.from_angle(a - 2.5) * 4.0])
		draw_colored_polygon(pts, Color(0.4, 0.75, 1.0))
