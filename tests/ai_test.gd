extends SceneTree
## Test AI: strzał gracza alarmuje wrogów; wrogowie korzystają z osłon, jeden flankuje, gracz dostaje obrażenia.
## godot --headless --fixed-fps 60 --path . --script res://tests/ai_test.gd

var _main: Node
var _frames := 0
var _visited := {}
var _enemies: Array = []


func _initialize() -> void:
	seed(7)
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		for c in _main.get_children():
			if c is Enemy:
				_enemies.append(c)
		var p: Player = _main.player
		p.global_position = Vector2(14 * 32 + 16, 5 * 32 + 16)  # w prawym pokoju, w zasięgu wzroku
		p.weapon.noise_radius = 400.0
		root.get_node("Events").emit_noise(p.global_position, 400.0, p)
	if _frames > 2:
		for e in _enemies:
			var k: String = e.state_name() + ("+" + e.role if e.role != "" else "")
			_visited[k] = true
	if _frames == 60 * 25:
		var p: Player = _main.player
		var any_cover := _visited.has("to_cover+suppress") or _visited.has("in_cover+suppress") or _visited.has("peek+suppress")
		var any_flank := false
		for k in _visited:
			if k.ends_with("+flank") or k.begins_with("flank"):
				any_flank = true
		var hurt: bool = p.body.total_frac() < 1.0 or p.body.blood < 100.0 or not p.body.alive
		print("AI states: ", _visited.keys())
		print("player hp frac=", p.body.total_frac(), " blood=", p.body.blood, " alive=", p.body.alive)
		var ok := any_cover and any_flank and hurt
		print("AI TEST ", "OK" if ok else "FAIL")
		quit(0 if ok else 1)
	return false
