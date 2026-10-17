class_name GridNav
extends RefCounted
## Nawigacja siatkowa (A*) i pomocnicze zapytania o linię widzenia na siatce.

var tile: int
var size: Vector2i
var solid: Array = []  # solid[y][x] : bool
var astar := AStarGrid2D.new()


func _init(level: Array, tile_size: int) -> void:
	tile = tile_size
	size = Vector2i(String(level[0]).length(), level.size())
	for y in size.y:
		var row := []
		for x in size.x:
			var ch: String = String(level[y])[x]
			row.append(ch == "#" or ch == "c")
		solid.append(row)
	astar.region = Rect2i(0, 0, size.x, size.y)
	astar.cell_size = Vector2(tile, tile)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in size.y:
		for x in size.x:
			if solid[y][x]:
				astar.set_point_solid(Vector2i(x, y), true)


func to_cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / tile)), int(floor(p.y / tile)))


func center(c: Vector2i) -> Vector2:
	return Vector2(c.x * tile + tile / 2.0, c.y * tile + tile / 2.0)


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y


func is_solid(c: Vector2i) -> bool:
	return not in_bounds(c) or solid[c.y][c.x]


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := to_cell(from)
	var b := to_cell(to)
	if is_solid(a) or is_solid(b):
		return PackedVector2Array()
	var cells := astar.get_id_path(a, b)
	var out := PackedVector2Array()
	for c in cells:
		out.append(center(c))
	return out


## Linia widzenia na siatce (krok co pół kafelka); ściany i osłony blokują.
func has_los(a: Vector2, b: Vector2) -> bool:
	var dist := a.distance_to(b)
	var steps := int(dist / (tile * 0.5)) + 1
	for i in range(1, steps):
		var p := a.lerp(b, float(i) / steps)
		if is_solid(to_cell(p)):
			return false
	return true


func free_cells_near(origin: Vector2, radius_tiles: int) -> Array:
	var out := []
	var c0 := to_cell(origin)
	for dy in range(-radius_tiles, radius_tiles + 1):
		for dx in range(-radius_tiles, radius_tiles + 1):
			var c := c0 + Vector2i(dx, dy)
			if not is_solid(c):
				out.append(c)
	return out
