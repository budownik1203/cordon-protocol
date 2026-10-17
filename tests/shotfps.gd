extends SceneTree
## Zrzut próbnej sceny 3D: godot --path . --script res://tests/shot3d.gd -- <seed> <biome> <out.png> <frames> [tryb]
var _frames := 0
var _scene: Node
var _out := "/tmp/shots/p3d.png"
var _wait := 60
var _mode := ""


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[2]
	_wait = int(a[3])
	if a.size() > 4:
		_mode = a[4]
	_scene = load("res://scenes/protofps.tscn").instantiate()
	root.add_child(_scene)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 8:
		_scene.player.yaw = -1.2
		pass
	if _frames == 10 and _mode == "fight":
		var p = _scene.player
		p.want_dir = Vector3(1, 0, 0)
		var e = _scene.enemies[0]
		e.global_position = p.global_position + Vector3(7, 0, 0)
		var e2 = _scene.enemies[1]
		e2.global_position = p.global_position + Vector3(6, 0, 3)
		p.body.hp[Body.Part.R_ARM] = 20.0
	if _mode == "fight" and _frames > 12 and _frames % 7 == 0:
		_scene.player._cooldown = 0.0
		_scene.player._fire()
	if _frames == _wait:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(_out)
		print("saved ", _out, " ", img.get_size())
		quit(0)
	return false
