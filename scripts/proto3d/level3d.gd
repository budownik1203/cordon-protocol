class_name Level3D
extends Node3D
## Buduje poziom 3D z siatki znaków generatora: '#' ściana, 'c' osłona, '.' podłoga. 1 kafelek = 1 m.

const WALL_H := 2.6
const COVER_H := 1.05

var rows: Array = []
var biome: String = "przedmiescia"


func build(p_rows: Array, p_biome: String) -> void:
	rows = p_rows
	biome = p_biome
	var pal := _palette()
	_build_floor(pal)
	_build_solids(pal)


func _palette() -> Dictionary:
	if biome == "kompleks":
		return {"floor_a": Color(0.5, 0.57, 0.6), "floor_b": Color(0.45, 0.52, 0.55), "wall": Color(0.38, 0.45, 0.5),
			"cap": Color(0.62, 0.7, 0.74), "cover": Color(0.55, 0.57, 0.5)}
	return {"floor_a": Color(0.46, 0.46, 0.42), "floor_b": Color(0.4, 0.4, 0.37), "wall": Color(0.5, 0.38, 0.3),
		"cap": Color(0.62, 0.52, 0.45), "cover": Color(0.5, 0.55, 0.38)}


func is_floor(x: int, y: int) -> bool:
	if y < 0 or y >= rows.size() or x < 0 or x >= String(rows[y]).length():
		return false
	var ch: String = rows[y][x]
	return ch != "#" and ch != " "


func _build_floor(pal: Dictionary) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch == "#" or ch == " ":
				continue
			var h: int = ((x * 73856093) ^ (y * 19349663)) & 0xffff
			var base: Color = pal["floor_a"].lerp(pal["floor_b"], float(h % 100) / 100.0)
			if (x / 2 + y / 2) % 2 == 0:
				base = base.darkened(0.05)  # plamy płyt 2x2, bez szachownicy
			var g := 0.025  # szczelina między płytami
			var a := Vector3(x + g, 0, y + g)
			var b := Vector3(x + 1 - g, 0, y + g)
			var c := Vector3(x + 1 - g, 0, y + 1 - g)
			var d := Vector3(x + g, 0, y + 1 - g)
			st.set_normal(Vector3.UP)
			st.set_color(base)
			for v in [a, b, c, a, c, d]:
				st.set_normal(Vector3.UP)
				st.set_color(base)
				st.add_vertex(v)
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	mi.material_override = m
	add_child(mi)
	# jedna duża płaska kolizja podłogi
	var body := StaticBody3D.new()
	body.collision_layer = 8
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	var w: int = String(rows[0]).length()
	bs.size = Vector3(w, 0.2, rows.size())
	cs.shape = bs
	cs.position = Vector3(w / 2.0, -0.1, rows.size() / 2.0)
	body.add_child(cs)
	add_child(body)


func _runs(ch: String) -> Array:
	# zwraca [x, y, długość] poziomych ciągów znaku
	var out := []
	for y in rows.size():
		var row: String = rows[y]
		var x := 0
		while x < row.length():
			if row[x] == ch:
				var x2 := x
				while x2 < row.length() and row[x2] == ch:
					x2 += 1
				out.append([x, y, x2 - x])
				x = x2
			else:
				x += 1
	return out


func _build_solids(pal: Dictionary) -> void:
	var wall_mesh := ArrayMesh.new()
	var body := StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	var wall_st := SurfaceTool.new()
	wall_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cap_st := SurfaceTool.new()
	cap_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in _runs("#"):
		var x: int = r[0]
		var y: int = r[1]
		var n: int = r[2]
		var bm := BoxMesh.new()
		bm.size = Vector3(n, WALL_H, 1)
		wall_st.append_from(bm, 0, Transform3D(Basis(), Vector3(x + n / 2.0, WALL_H / 2.0, y + 0.5)))
		var cm := BoxMesh.new()
		cm.size = Vector3(n + 0.06, 0.12, 1.06)
		cap_st.append_from(cm, 0, Transform3D(Basis(), Vector3(x + n / 2.0, WALL_H + 0.02, y + 0.5)))
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(n, WALL_H, 1)
		cs.shape = bs
		cs.position = Vector3(x + n / 2.0, WALL_H / 2.0, y + 0.5)
		body.add_child(cs)
	var wm := wall_st.commit()
	var wmi := MeshInstance3D.new()
	wmi.mesh = wm
	wmi.material_override = LowPolyFigure._mat(pal["wall"], 1.0)
	add_child(wmi)
	var cmi := MeshInstance3D.new()
	cmi.mesh = cap_st.commit()
	cmi.material_override = LowPolyFigure._mat(pal["cap"], 1.0)
	add_child(cmi)
	# osłony: niskie skrzynie/kontenery, które blokują ruch i kule (tak jak w 2D)
	for r in _runs("c"):
		var x2: int = r[0]
		var y2: int = r[1]
		var n2: int = r[2]
		var mi := MeshInstance3D.new()
		var bm2 := BoxMesh.new()
		bm2.size = Vector3(n2 - 0.1, COVER_H, 0.85)
		mi.mesh = bm2
		mi.material_override = LowPolyFigure._mat(pal["cover"], 0.95)
		mi.position = Vector3(x2 + n2 / 2.0, COVER_H / 2.0, y2 + 0.5)
		add_child(mi)
		var top := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(n2 - 0.0, 0.1, 0.95)
		top.mesh = tm
		top.material_override = LowPolyFigure._mat(Color(pal["cover"]).darkened(0.25), 0.95)
		top.position = Vector3(x2 + n2 / 2.0, COVER_H + 0.03, y2 + 0.5)
		add_child(top)
		var cs2 := CollisionShape3D.new()
		var bs2 := BoxShape3D.new()
		bs2.size = Vector3(n2, COVER_H, 1)
		cs2.shape = bs2
		cs2.position = Vector3(x2 + n2 / 2.0, COVER_H / 2.0, y2 + 0.5)
		body.add_child(cs2)
