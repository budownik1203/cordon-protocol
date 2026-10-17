class_name LowPolyFigure
extends Node3D
## Postać z kilku sześcianów (low poly), zwrócona przodem w stronę -Z. Animuje chód i odrzut.

var legs: Array = []  # piwoty nóg
var arms: Array = []
var torso_node: Node3D
var gun: Node3D
var head: MeshInstance3D
var _t: float = 0.0
var recoil: float = 0.0


static func _mat(c: Color, rough: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


func build(skin: Color, cloth: Color, vest: Color, helmet: Color, has_vest: bool, has_helmet: bool, gun_c: Color) -> void:
	torso_node = Node3D.new()
	add_child(torso_node)
	_box(torso_node, Vector3(0.52, 0.6, 0.28), Vector3(0, 1.15, 0), cloth)
	if has_vest:
		_box(torso_node, Vector3(0.58, 0.46, 0.34), Vector3(0, 1.18, 0), vest)
	head = _box(torso_node, Vector3(0.26, 0.28, 0.26), Vector3(0, 1.62, 0), skin)
	if has_helmet:
		_box(torso_node, Vector3(0.32, 0.14, 0.32), Vector3(0, 1.74, 0), helmet)
	else:
		_box(torso_node, Vector3(0.28, 0.08, 0.28), Vector3(0, 1.76, 0), cloth.darkened(0.3))
	for sx in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(sx * 0.12, 0.85, 0)
		add_child(pivot)
		_box(pivot, Vector3(0.2, 0.85, 0.22), Vector3(0, -0.42, 0), cloth.darkened(0.25))
		legs.append(pivot)
	for sx in [-1.0, 1.0]:
		var ap := Node3D.new()
		ap.position = Vector3(sx * 0.34, 1.4, 0)
		torso_node.add_child(ap)
		_box(ap, Vector3(0.13, 0.55, 0.13), Vector3(0, -0.27, 0), cloth)
		_box(ap, Vector3(0.14, 0.12, 0.14), Vector3(0, -0.58, 0), skin)
		ap.rotation.x = -1.25  # ręce uniesione do przodu, trzymają broń
		ap.rotation.y = -sx * 0.25
		arms.append(ap)
	gun = Node3D.new()
	gun.position = Vector3(0.0, 1.18, -0.42)
	torso_node.add_child(gun)
	_box(gun, Vector3(0.08, 0.12, 0.7), Vector3(0, 0, -0.1), gun_c)
	_box(gun, Vector3(0.06, 0.2, 0.08), Vector3(0, -0.12, 0.05), gun_c.darkened(0.2))
	_box(gun, Vector3(0.05, 0.05, 0.25), Vector3(0, 0.03, -0.55), gun_c.lightened(0.1))


func animate(delta: float, speed_norm: float, sprint: bool) -> void:
	_t += delta * (4.0 + 6.0 * speed_norm) * (1.3 if sprint else 1.0)
	var swing := sin(_t) * 0.75 * speed_norm
	if legs.size() == 2:
		legs[0].rotation.x = swing
		legs[1].rotation.x = -swing
	torso_node.position.y = absf(sin(_t)) * 0.06 * speed_norm
	torso_node.rotation.z = sin(_t) * 0.05 * speed_norm
	recoil = move_toward(recoil, 0.0, delta * 8.0)
	if gun:
		gun.position.z = -0.42 + recoil * 0.12
	torso_node.rotation.x = -recoil * 0.05 + (0.12 if sprint else 0.0)
