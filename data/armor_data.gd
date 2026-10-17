class_name ArmorData
extends Resource
## Pancerz: klasa 1–6 kontra penetracja amunicji; zużywa się przy trafieniach.

@export var display_name: String = "Kamizelka"
@export_range(1, 6) var armor_class: int = 3
@export var max_durability: float = 60.0
var durability: float = 60.0


static func make(name: String, cls: int, dur: float) -> ArmorData:
	var a := ArmorData.new()
	a.display_name = name
	a.armor_class = cls
	a.max_durability = dur
	a.durability = dur
	return a


## Zwraca mnożnik obrażeń po przejściu przez pancerz i zużywa wytrzymałość.
func absorb(damage: float, penetration: int) -> float:
	if durability <= 0.0:
		return 1.0
	var diff := penetration - armor_class
	var mult := 1.0
	if diff >= 1:
		mult = 0.75
	elif diff == 0:
		mult = 0.5
	else:
		mult = 0.2
	durability = maxf(0.0, durability - damage * 0.15 * (1.0 + maxf(0, diff) * 0.5))
	# zużyty pancerz chroni gorzej
	return lerpf(1.0, mult, clampf(durability / max_durability + 0.25, 0.0, 1.0))
