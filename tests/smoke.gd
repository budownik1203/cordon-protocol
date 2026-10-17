extends SceneTree
## Test dymny: uruchamia główną scenę, strzela w manekin i sprawdza trafienie.
## Uruchomienie: godot --headless --path . --script res://tests/smoke.gd

var _frames := 0
var _main: Node
var _player
var _target


func _initialize() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 3:
		_player = _main.player
		for c in _main.get_children():
			if c.has_method("take_hit") and "killed_once" in c:
				_target = c
				break
		# ustaw gracza przed manekinem bez przeszkód i patrz w jego stronę
		_player.global_position = _target.global_position - Vector2(80, 0)
		_player.weapon.base_spread_deg = 0.0
		_player.weapon.move_spread_deg = 0.0
		_player.weapon.recoil_per_shot_deg = 0.0
		_player.weapon_item.mag.loaded = 30
	if _frames > 3 and _frames < 40:
		_player.global_position = _target.global_position - Vector2(80, 0)
		_player._aim_dir = Vector2.RIGHT
		_player._cooldown = 0.0
		_player._fire()
	if _frames == 40:
		var ok: bool = _target.hp <= 0.0 and _player.ammo < 30
		print("SMOKE ", "OK" if ok else "FAIL", " hp=", _target.hp, " ammo=", _player.ammo)
		quit(0 if ok else 1)
	return false
