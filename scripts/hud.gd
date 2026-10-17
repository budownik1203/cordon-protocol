extends Label
## Minimalny HUD prototypu: amunicja i rozrzut.

var _player: Player


func setup(player: Player) -> void:
	_player = player
	player.ammo_changed.connect(_on_ammo)
	_on_ammo(player.ammo, player.weapon.magazine_size, false)


func _on_ammo(in_mag: int, mag_size: int, reloading: bool) -> void:
	text = "%s  %d/%d%s" % [_player.weapon.display_name, in_mag, mag_size, "  (przeładowanie)" if reloading else ""]
