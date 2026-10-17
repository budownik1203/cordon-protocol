extends Label
## HUD: broń i amunicja, wytrzymałość, waga, stan ciała, zapasy leczenia, czas i zagrożenie rajdu.

var _player: Player
var raid: Node = null


func setup(player: Player) -> void:
	_player = player


func _process(_delta: float) -> void:
	if _player == null:
		return
	var eq := _player.equipment
	var lines := PackedStringArray()
	if _player.weapon:
		var mags := PackedStringArray()
		for m in _player.spare_mags():
			mags.append(str(m["item"].loaded))
		var wi: Item = _player.weapon_item
		var head := "%s  %s" % [_player.weapon.display_name, str(_player.ammo) if wi.mag != null else "brak mag."]
		lines.append("%s   zapas: %s   luzem: %d" % [head, " ".join(mags) if mags.size() > 0 else "-", _player.loose_ammo()])
		if _player.reloading:
			lines.append("  %s" % ("wymiana magazynka..." if _player.reload_kind == "swap" else "dobijanie naboi (strzał przerywa)..."))
		elif _player.loading_mags:
			lines.append("  pakowanie magazynków (V)... strzał lub bieg przerywa")
	else:
		lines.append("Brak broni")
	lines.append("Wytrzymałość %d  |  %.1f kg (%s)" % [int(_player.stamina), eq.total_weight(),
		Equipment.LOAD_NAMES[eq.load_level()]])
	lines.append_array(_player.body.status_lines())
	lines.append("[1] bandaż %d  [2] hemostat. %d  [3] szyna %d  [4] środek %d" % [
		eq.count_of("bandage"), eq.count_of("hemostatic"), eq.count_of("splint"), eq.count_of("painkiller")])
	if _player.using_item != "":
		lines.append("Używasz: %s" % _player.using_item)
	if raid:
		var t: float = raid.elapsed
		lines.append("%s   Czas %02d:%02d   Zagrożenie %d" % [raid.bdef.get("short", ""), int(t) / 60, int(t) % 60, int(raid.threat)])
		lines.append("[M] mapa  [Tab] ekwipunek  [E] przeszukaj  [R] magazynek  [V] pakuj mag.")
	if not _player.is_alive():
		lines.append("")
		lines.append("NIE ŻYJESZ: %s" % _player.body.cause_of_death)
	text = "\n".join(lines)
