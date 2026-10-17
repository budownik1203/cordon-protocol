class_name Body
extends RefCounted
## Model ciała: 5 części, krwawienie, złamanie, ból. Używany przez gracza i wrogów.

signal died(cause: String)

enum Part { HEAD, CHEST, ABDOMEN, ARMS, LEGS }

const PART_NAMES := {
	Part.HEAD: "Głowa", Part.CHEST: "Klatka", Part.ABDOMEN: "Brzuch",
	Part.ARMS: "Ręce", Part.LEGS: "Nogi",
}
const MAX_HP := {
	Part.HEAD: 35.0, Part.CHEST: 85.0, Part.ABDOMEN: 70.0,
	Part.ARMS: 60.0, Part.LEGS: 65.0,
}
## Wagi losowania trafionej części ciała (widok z góry nie ma wysokości).
const HIT_WEIGHTS := {
	Part.HEAD: 0.08, Part.CHEST: 0.32, Part.ABDOMEN: 0.2,
	Part.ARMS: 0.2, Part.LEGS: 0.2,
}
const LIGHT_BLEED := 0.35  # krew/s
const HEAVY_BLEED := 1.2

var hp: Dictionary = {}
var blood: float = 100.0
var light_bleeds: int = 0
var heavy_bleeds: int = 0
var leg_fracture: bool = false
var pain: float = 0.0  # 0..1
var painkiller_time: float = 0.0
var helmet: ArmorData
var vest: ArmorData
var alive: bool = true
var cause_of_death: String = ""


func _init() -> void:
	for p in MAX_HP:
		hp[p] = MAX_HP[p]


func pick_part() -> int:
	var r := randf()
	var acc := 0.0
	for p in HIT_WEIGHTS:
		acc += HIT_WEIGHTS[p]
		if r <= acc:
			return p
	return Part.CHEST


func apply_hit(part: int, damage: float, penetration: int = 2) -> float:
	if not alive:
		return 0.0
	var dmg := damage
	if part == Part.HEAD and helmet:
		dmg *= helmet.absorb(damage, penetration)
	elif (part == Part.CHEST or part == Part.ABDOMEN) and vest:
		dmg *= vest.absorb(damage, penetration)
	hp[part] = maxf(0.0, hp[part] - dmg)
	pain = clampf(pain + dmg / 120.0, 0.0, 1.0)
	_roll_conditions(part, dmg)
	if hp[Part.HEAD] <= 0.0:
		_die("Zniszczenie głowy")
	elif hp[Part.CHEST] <= 0.0:
		_die("Zniszczenie klatki piersiowej")
	return dmg


func _roll_conditions(part: int, dmg: float) -> void:
	if part == Part.HEAD:
		return
	if dmg >= 30.0 and randf() < 0.35:
		heavy_bleeds += 1
	elif dmg >= 12.0 and randf() < 0.45:
		light_bleeds += 1
	if part == Part.LEGS and dmg >= 22.0 and randf() < 0.3:
		leg_fracture = true


func tick(delta: float) -> void:
	if not alive:
		return
	blood -= (light_bleeds * LIGHT_BLEED + heavy_bleeds * HEAVY_BLEED) * delta
	if painkiller_time > 0.0:
		painkiller_time -= delta
		pain = maxf(0.0, pain - 0.15 * delta)
	else:
		pain = maxf(0.0, pain - 0.01 * delta)
	if blood <= 0.0:
		_die("Wykrwawienie")


func _die(cause: String) -> void:
	alive = false
	cause_of_death = cause
	died.emit(cause)


func frac(part: int) -> float:
	return hp[part] / MAX_HP[part]


func total_frac() -> float:
	var sum := 0.0
	var mx := 0.0
	for p in MAX_HP:
		sum += hp[p]
		mx += MAX_HP[p]
	return sum / mx


func speed_mult() -> float:
	var m := 1.0 - (1.0 - frac(Part.LEGS)) * 0.35
	if leg_fracture:
		m *= 0.6
	return m


func spread_mult() -> float:
	return 1.0 + (1.0 - frac(Part.ARMS)) * 0.8 + pain * 0.8


func reload_mult() -> float:
	return 1.0 + (1.0 - frac(Part.ARMS)) * 0.6


## Leczenie: zwraca true, jeśli coś naprawiło.
func use_bandage() -> bool:
	if light_bleeds > 0:
		light_bleeds = 0
		return true
	return false


func use_hemostatic() -> bool:
	if heavy_bleeds > 0 or light_bleeds > 0:
		heavy_bleeds = 0
		light_bleeds = 0
		return true
	return false


func use_splint() -> bool:
	if leg_fracture:
		leg_fracture = false
		return true
	return false


func use_painkiller() -> bool:
	painkiller_time = 60.0
	return true


func status_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for p in Part.values():
		lines.append("%-7s %3d/%d" % [PART_NAMES[p], int(hp[p]), int(MAX_HP[p])])
	var flags := []
	if light_bleeds > 0:
		flags.append("krwawienie x%d" % light_bleeds)
	if heavy_bleeds > 0:
		flags.append("CIĘŻKIE krwawienie x%d" % heavy_bleeds)
	if leg_fracture:
		flags.append("złamanie nogi")
	if pain > 0.25:
		flags.append("ból")
	lines.append("Krew    %d%%" % int(blood))
	if flags.size() > 0:
		lines.append(", ".join(flags))
	return lines
