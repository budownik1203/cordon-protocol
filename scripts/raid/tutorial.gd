class_name Tutorial
extends Node
## Szkolenie: krótka seria kroków z podpowiedziami, każdy zalicza się po wykonaniu czynności.

const STEPS := [
	"RUCH: WASD. Shift to sprint (głośno!), C to skradanie. Przejdź do następnego pokoju.",
	"CELOWANIE: mysz. LPM strzela. Widzisz tylko w stożku światła, reszta jest ciemna. Zniszcz oba manekiny.",
	"PRZEŁADOWANIE: naciśnij R. Amunicja z kamizelki, pasa i kieszeni ładuje się szybciej niż z plecaka.",
	"PRZESZUKIWANIE: podejdź do szafki i naciśnij E. Zawartość odsłania się po kolei, a hałas przyciąga uwagę.",
	"EKWIPUNEK: LPM bierze przedmiot, PPM przenosi lub zakłada, R obraca. Amunicję przeciągnij na magazynek, by go załadować. Zabierz wszystko i zamknij (Tab).",
	"WRÓG: w ostatnim pokoju czeka szabrownik. Użyj osłon, strzelaj z ukrycia. Leczenie: klawisze 1-9 (pasek szybkiego dostępu) albo przeciągnij środek na część ciała w ekwipunku.",
	"WYJŚCIE: stań w zielonej strefie przez 6 sekund. Mapa pod klawiszem M.",
]

var raid: Node2D
var step: int = 0
var targets: Array = []
var _from := Vector2.ZERO
var _inv_seen := false
var _reload_seen := false
var _label: Label


func setup(r: Node2D, tgts: Array, label: Label) -> void:
	raid = r
	targets = tgts
	_label = label
	_from = raid.player.global_position
	_show()


func _show() -> void:
	if _label:
		_label.text = "[%d/%d] %s" % [step + 1, STEPS.size(), STEPS[mini(step, STEPS.size() - 1)]]


func _advance() -> void:
	step += 1
	Audio.play("pickup", -6.0)
	if step < STEPS.size():
		_show()


func _kills_total() -> int:
	var n := 0
	for k in raid.stats["kills"]:
		n += int(raid.stats["kills"][k])
	return n


func _process(_delta: float) -> void:
	if raid == null or raid.finished or step >= STEPS.size():
		return
	var p: Player = raid.player
	if p.reloading:
		_reload_seen = true
	match step:
		0:
			if p.global_position.distance_to(_from) > 150.0:
				_advance()
		1:
			var all := true
			for t in targets:
				if is_instance_valid(t) and not t.killed_once:
					all = false
			if all:
				_advance()
		2:
			if _reload_seen and not p.reloading:
				_advance()
		3:
			if raid.stats["boxes_opened"] >= 1:
				_advance()
		4:
			if raid.inv_ui.visible:
				_inv_seen = true
			elif _inv_seen:
				_advance()
		5:
			if _kills_total() >= 1:
				_advance()
