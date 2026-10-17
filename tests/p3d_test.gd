extends SceneTree
## Test próbnej sceny 3D: buduje się bez błędów, gracz się porusza i strzela, wróg ginie.
var _frames := 0
var _scene: Node
var _fail := 0


func _ok(c: bool, m: String) -> void:
	if not c:
		_fail += 1
		print("FAIL ", m)


func _initialize() -> void:
	_scene = load("res://scenes/proto3d.tscn").instantiate()
	root.add_child(_scene)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 5:
		_ok(_scene.enemies.size() > 3, "wrogowie: %d" % _scene.enemies.size())
		_ok(_scene.crates.size() > 5, "skrzynie: %d" % _scene.crates.size())
		var p = _scene.player
		var e = _scene.enemies[0]
		# ustaw wroga przed graczem i zabij go serią
		e.global_position = p.global_position + Vector3(0, 0, -6)
		p.global_position = Vector3(p.global_position.x, 0, p.global_position.z)
		p.yaw = 0.0
		p.want_dir = Vector3(0, 0, -1)
		for i in 80:
			e.take_hit(40.0, Vector3(0, 0, -1), 4)
		_ok(e._dead, "wróg martwy po serii")
		_ok(p.body.alive, "gracz żyje")
	if _frames == 30:
		var p2 = _scene.player
		var before = p2.global_position
		Input.action_press("move_right")
	if _frames == 90:
		Input.action_release("move_right")
		_ok(_scene.player.velocity.length() >= 0.0, "ruch")
		print("P3D TEST ", "OK" if _fail == 0 else "FAIL(%d)" % _fail)
		quit(0 if _fail == 0 else 1)
	return false
