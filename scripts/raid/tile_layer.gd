class_name TileLayer
extends Node2D
## Statyczna warstwa kafelków poziomu (rysowana raz): podłoga, ściany, osłony, pokój anomalii.

const TILE := 32
var rows: Array = []
var biome_tiles: String = "a"
var anomaly_rect := Rect2i(-1, -1, 0, 0)


func setup(p_rows: Array, p_tiles: String, p_anomaly: Rect2i) -> void:
	rows = p_rows
	biome_tiles = p_tiles
	anomaly_rect = p_anomaly
	queue_redraw()


func _floor_tex(x: int, y: int) -> Texture2D:
	if anomaly_rect.has_point(Vector2i(x, y)):
		return Assets.tex("floor_x%d" % ((x + y) % 2))
	var h: int = ((x * 73856093) ^ (y * 19349663)) & 0xffff
	var v := h % 10
	var idx := 0
	if v >= 5 and v < 7:
		idx = 1
	elif v >= 7 and v < 9:
		idx = 2
	elif v == 9:
		idx = 3
	return Assets.tex("floor_%s%d" % [biome_tiles, idx])


func _draw() -> void:
	var wall := Assets.tex("wall_" + biome_tiles)
	var cover := Assets.tex("cover_" + biome_tiles)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch == " ":
				continue
			var r := Rect2(x * TILE, y * TILE, TILE, TILE)
			if ch == "#":
				if wall:
					draw_texture_rect(wall, r, false)
				else:
					draw_rect(r, Color(0.3, 0.32, 0.36))
				continue
			var ft := _floor_tex(x, y)
			if ft:
				draw_texture_rect(ft, r, false)
			else:
				draw_rect(r, Color(0.38, 0.38, 0.36))
			if ch == "c":
				if cover:
					draw_texture_rect(cover, r, false)
				else:
					draw_rect(r.grow(-4), Color(0.45, 0.4, 0.3))
