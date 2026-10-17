extends Label
## HUD prototypu: broń, amunicja, stan ciała, zapasy leczenia.

var _player: Player
var _ammo_text := ""


func setup(player: Player) -> void:
	_player = player
	player.ammo_changed.connect(_on_ammo)
	_on_ammo(player.ammo, player.weapon.magazine_size, false)


func _on_ammo(in_mag: int, mag_size: int, reloading: bool) -> void:
	_ammo_text = "%s  %d/%d%s" % [_player.weapon.display_name, in_mag, mag_size,
		"  (przeładowanie)" if reloading else ""]


func _process(_delta: float) -> void:
	if _player == null:
		return
	var s: Dictionary = _player.supplies
	var lines := PackedStringArray()
	lines.append(_ammo_text)
	lines.append_array(_player.body.status_lines())
	lines.append("[1] bandaż %d  [2] hemostatyk %d  [3] szyna %d  [4] środek %d" % [
		s.bandage, s.hemostatic, s.splint, s.painkiller])
	if _player.using_item != "":
		lines.append("Używasz: %s" % _player.using_item)
	if not _player.is_alive():
		lines.append("")
		lines.append("NIE ŻYJESZ: %s" % _player.body.cause_of_death)
		lines.append("Enter - jeszcze raz")
	text = "\n".join(lines)
