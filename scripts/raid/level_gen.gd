class_name LevelGen
extends RefCounted
## Generator rajdu: graf pokoi na makrosiatce, pokoje składane z ręcznie robionych kawałków.
## Gwarancje: ścieżka do 2 wyjść, minimum miejsc na łup, pokój startowy bez wrogów.

const COLS := 4
const ROWS := 3
const RW := 16  # szerokość pokoju w kafelkach
const RH := 12
const TILE := 32

## Kawałki 6x4 wypełniające ćwiartki pokoju. # ściana, c osłona, L łup.
const PIECES := [
	["......", "......", "......", "......"],
	["..cc..", "......", "......", "..cc.."],
	["#....L", "#.....", "#.....", "######"],
	[".c..c.", "......", ".c..c.", "......"],
	["cccc..", "......", "..L...", "......"],
	["##.##.", "#....L", "#.....", "##.###"],
	["..L...", "cc.cc.", "......", "......"],
	["......", "..##..", "..##..", "......"],
	["L..c..", "...c..", "...c..", "...cL."],
	["......", ".cccc.", "......", "L....."],
	["L.....", "c.....", "c....L", "cccc.."],
	["#.#.#.", "......", "......", "L.L..."],
]

var rng := RandomNumberGenerator.new()
var grid: Array = []  # grid[y][x] : String (znak)
var rooms: Dictionary = {}  # Vector2i -> {"edges": [Vector2i], ...}
var start_room := Vector2i.ZERO
var exit_rooms: Array = []
var result: Dictionary = {}


func generate(seed_value: int) -> Dictionary:
	rng.seed = seed_value
	_build_graph()
	_compose()
	_carve_doors()
	_finalize()
	return result


func _build_graph() -> void:
	rooms.clear()
	var start := Vector2i(0, rng.randi_range(0, ROWS - 1))
	start_room = start
	rooms[start] = {"edges": []}
	var stack := [start]
	var target := rng.randi_range(8, 10)
	while stack.size() > 0 and rooms.size() < target:
		var cur: Vector2i = stack.back()
		var nbrs := []
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if n.x >= 0 and n.y >= 0 and n.x < COLS and n.y < ROWS and not rooms.has(n):
				nbrs.append(n)
		if nbrs.is_empty():
			stack.pop_back()
			continue
		var nxt: Vector2i = nbrs[rng.randi() % nbrs.size()]
		rooms[nxt] = {"edges": []}
		rooms[cur]["edges"].append(nxt)
		rooms[nxt]["edges"].append(cur)
		stack.append(nxt)
	# dodatkowe krawędzie tworzą pętle (alternatywne trasy)
	var extra := 0
	for r in rooms.keys():
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var n: Vector2i = r + d
			if rooms.has(n) and not rooms[r]["edges"].has(n) and extra < 2 and rng.randf() < 0.5:
				rooms[r]["edges"].append(n)
				rooms[n]["edges"].append(r)
				extra += 1
	# wyjścia: dwa najdalsze pokoje (w krokach grafu)
	var dist := _bfs(start_room)
	var sorted_rooms := rooms.keys()
	sorted_rooms.sort_custom(func(a, b): return dist[a] > dist[b])
	exit_rooms = [sorted_rooms[0]]
	for r in sorted_rooms:
		if r != exit_rooms[0] and r != start_room:
			exit_rooms.append(r)
			break


func _bfs(from: Vector2i) -> Dictionary:
	var dist := {from: 0}
	var q := [from]
	while q.size() > 0:
		var c: Vector2i = q.pop_front()
		for n in rooms[c]["edges"]:
			if not dist.has(n):
				dist[n] = dist[c] + 1
				q.append(n)
	return dist


func _flip(piece: Array, fx: bool, fy: bool) -> Array:
	var rows := piece.duplicate()
	if fy:
		rows.reverse()
	if fx:
		rows = rows.map(func(r): return String(r).reverse())
	return rows


func _compose() -> void:
	var W := COLS * RW
	var H := ROWS * RH
	grid.clear()
	for y in H:
		var row := []
		for x in W:
			row.append(" ")
		grid.append(row)
	for rp in rooms.keys():
		var ox: int = rp.x * RW
		var oy: int = rp.y * RH
		for y in RH:
			for x in RW:
				var border := x == 0 or y == 0 or x == RW - 1 or y == RH - 1
				grid[oy + y][ox + x] = "#" if border else "."
		var quads := [Vector2i(1, 1), Vector2i(9, 1), Vector2i(1, 7), Vector2i(9, 7)]
		for q in quads:
			var piece: Array = PIECES[rng.randi() % PIECES.size()]
			if rp == start_room:
				piece = PIECES[0] if rng.randf() < 0.6 else PIECES[1]
			if exit_rooms.has(rp) and q == Vector2i(1, 1):
				piece = PIECES[0]
			piece = _flip(piece, rng.randf() < 0.5, rng.randf() < 0.5)
			for py in 4:
				for px in 6:
					grid[oy + q.y + py][ox + q.x + px] = String(piece[py])[px]


func _carve_doors() -> void:
	for rp in rooms.keys():
		var ox: int = rp.x * RW
		var oy: int = rp.y * RH
		for n in rooms[rp]["edges"]:
			var d: Vector2i = n - rp
			if d == Vector2i(1, 0):
				for yy in [5, 6]:
					grid[oy + yy][ox + RW - 1] = "."
					grid[oy + yy][ox + RW] = "."
			elif d == Vector2i(-1, 0):
				for yy in [5, 6]:
					grid[oy + yy][ox] = "."
					grid[oy + yy][ox - 1] = "."
			elif d == Vector2i(0, 1):
				for xx in [7, 8]:
					grid[oy + RH - 1][ox + xx] = "."
					grid[oy + RH][ox + xx] = "."
			elif d == Vector2i(0, -1):
				for xx in [7, 8]:
					grid[oy][ox + xx] = "."
					grid[oy - 1][ox + xx] = "."


func _cell_px(x: int, y: int) -> Vector2:
	return Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)


func _finalize() -> void:
	var W := COLS * RW
	var H := ROWS * RH
	var start_cell := Vector2i(start_room.x * RW + 7, start_room.y * RH + 5)

	# wyjścia 2x2 w lewej górnej ćwiartce pokoju
	var exits := []
	var kinds := ["open", "key"]
	for i in exit_rooms.size():
		var rp: Vector2i = exit_rooms[i]
		var ox: int = rp.x * RW + 2
		var oy: int = rp.y * RH + 2
		for yy in 2:
			for xx in 2:
				grid[oy + yy][ox + xx] = "X"
		exits.append({"pos": _cell_px(ox, oy) + Vector2(TILE / 2.0, TILE / 2.0), "kind": kinds[i], "room": rp})

	# usuń łup nieosiągalny; sprawdź dostępność przez tymczasową nawigację
	var rows: Array = _rows()
	var nav := GridNav.new(rows, TILE)
	var loot := []
	var floor_cells := []
	for y in H:
		for x in W:
			var ch: String = grid[y][x]
			if ch == "L":
				var p := nav.find_path(_cell_px(start_cell.x, start_cell.y), _cell_px(x, y))
				if p.is_empty():
					grid[y][x] = "."
				else:
					loot.append(_cell_px(x, y))
			elif ch == ".":
				floor_cells.append(Vector2i(x, y))
	# minimalna liczba miejsc na łup
	var tries := 0
	while loot.size() < 12 and tries < 400:
		tries += 1
		var c: Vector2i = floor_cells[rng.randi() % floor_cells.size()]
		if grid[c.y][c.x] != ".":
			continue
		# przy ścianie, z dala od osi przejść
		var lx := c.x % RW
		var ly := c.y % RH
		if (lx >= 7 and lx <= 8) or (ly >= 5 and ly <= 6) or lx == 0 or ly == 0:
			continue
		if not (nav.is_solid(c + Vector2i(1, 0)) or nav.is_solid(c + Vector2i(-1, 0))
				or nav.is_solid(c + Vector2i(0, 1)) or nav.is_solid(c + Vector2i(0, -1))):
			continue
		if nav.find_path(_cell_px(start_cell.x, start_cell.y), _cell_px(c.x, c.y)).is_empty():
			continue
		grid[c.y][c.x] = "L"
		loot.append(_cell_px(c.x, c.y))

	# spawny wrogów
	var dist := _bfs(start_room)
	var spawns := []
	for rp in rooms.keys():
		if rp == start_room:
			continue
		var d: int = dist[rp]
		if rng.randf() > (0.55 + 0.1 * minf(d, 4.0)):
			continue
		var n := rng.randi_range(1, 2 if d < 3 else 3)
		var roll := rng.randf()
		var faction := "Szabrownicy"
		if roll > 0.88 or (exit_rooms.has(rp) and roll > 0.6):
			faction = "Wojskowi"
		elif roll > 0.62:
			faction = "Najemnicy"
		var cells := []
		var tries2 := 0
		while cells.size() < n and tries2 < 80:
			tries2 += 1
			var cx: int = rp.x * RW + rng.randi_range(2, RW - 3)
			var cy: int = rp.y * RH + rng.randi_range(2, RH - 3)
			if grid[cy][cx] == ".":
				cells.append(_cell_px(cx, cy))
		if not cells.is_empty():
			spawns.append({"faction": faction, "cells": cells, "room": rp})

	# komórki do spawnu fauny (z dala od startu)
	var fauna_cells := []
	for c in floor_cells:
		if Vector2(c).distance_to(Vector2(start_cell)) > 18.0 and grid[c.y][c.x] == ".":
			fauna_cells.append(_cell_px(c.x, c.y))

	result = {
		"rows": _rows(), "start": _cell_px(start_cell.x, start_cell.y), "exits": exits,
		"loot": loot, "spawns": spawns, "fauna_cells": fauna_cells,
		"size": Vector2i(W, H),
	}


func _rows() -> Array:
	var out := []
	for y in grid.size():
		var s := ""
		for x in grid[y].size():
			s += grid[y][x]
		out.append(s)
	return out
