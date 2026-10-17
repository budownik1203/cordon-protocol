class_name Body
extends RefCounted
## Model ciała w stylu Tarkova: 7 części z własnym HP, krwawienia i złamania przypisane do części,
## kończyny mogą zostać zniszczone (0 HP) i naprawione zestawem chirurgicznym. Śmierć: głowa lub klatka na 0.
## Używany przez gracza i wrogów.

signal died(cause: String)

enum Part { HEAD, CHEST, STOMACH, L_ARM, R_ARM, L_LEG, R_LEG }

const PARTS := [Part.HEAD, Part.CHEST, Part.STOMACH, Part.L_ARM, Part.R_ARM, Part.L_LEG, Part.R_LEG]
const LIMBS := [Part.L_ARM, Part.R_ARM, Part.L_LEG, Part.R_LEG]

const PART_NAMES := {
	Part.HEAD: "Głowa", Part.CHEST: "Klatka", Part.STOMACH: "Brzuch",
	Part.L_ARM: "Lewa ręka", Part.R_ARM: "Prawa ręka", Part.L_LEG: "Lewa noga", Part.R_LEG: "Prawa noga",
}
const MAX_HP := {
	Part.HEAD: 35.0, Part.CHEST: 85.0, Part.STOMACH: 70.0,
	Part.L_ARM: 60.0, Part.R_ARM: 60.0, Part.L_LEG: 65.0, Part.R_LEG: 65.0,
}
## Wagi losowania trafionej części (widok z góry nie ma wysokości).
const HIT_WEIGHTS := {
	Part.HEAD: 0.07, Part.CHEST: 0.28, Part.STOMACH: 0.15,
	Part.L_ARM: 0.1, Part.R_ARM: 0.1, Part.L_LEG: 0.15, Part.R_LEG: 0.15,
}
const LIGHT_BLEED := 0.25  # HP/s z części
const HEAVY_BLEED := 0.9
## Ułamek obrażeń nadmiarowych (ponad 0 HP części), który rozchodzi się na resztę ciała.
const OVERFLOW_SHARE := 0.7
## Po naprawie zniszczonej kończyny: HP i spadek maksymalnego HP (jak kara za operację w Tarkovie).
const RESTORE_HP_FRAC := 0.3
const RESTORE_MAX_PENALTY := 0.2

var hp: Dictionary = {}
var max_hp: Dictionary = {}
var bleed: Dictionary = {}  # część -> 0 brak, 1 lekkie, 2 ciężkie
var fracture: Dictionary = {}  # część (tylko kończyny) -> bool
var pain: float = 0.0  # 0..1
var painkiller_time: float = 0.0
var helmet: ArmorData
var vest: ArmorData
var alive: bool = true
var cause_of_death: String = ""


func _init() -> void:
	for p in PARTS:
		hp[p] = MAX_HP[p]
		max_hp[p] = MAX_HP[p]
		bleed[p] = 0
		fracture[p] = false


func pick_part() -> int:
	var r := randf()
	var acc := 0.0
	for p in HIT_WEIGHTS:
		acc += HIT_WEIGHTS[p]
		if r <= acc:
			return p
	return Part.CHEST


func is_limb(part: int) -> bool:
	return part in LIMBS


func is_leg(part: int) -> bool:
	return part == Part.L_LEG or part == Part.R_LEG


## Zniszczona (0 HP). Głowa i klatka na 0 oznaczają śmierć, więc to dotyczy reszty.
func blacked(part: int) -> bool:
	return hp[part] <= 0.0


func apply_hit(part: int, damage: float, penetration: int = 2) -> float:
	if not alive:
		return 0.0
	var dmg := damage
	if part == Part.HEAD and helmet:
		dmg *= helmet.absorb(damage, penetration)
	elif (part == Part.CHEST or part == Part.STOMACH) and vest:
		dmg *= vest.absorb(damage, penetration)
	var was_blacked := blacked(part)
	var new_hp: float = hp[part] - dmg
	var overflow := 0.0
	if new_hp < 0.0:
		overflow = -new_hp
		new_hp = 0.0
	hp[part] = new_hp
	pain = clampf(pain + dmg / 120.0, 0.0, 1.0)
	if not was_blacked:
		_roll_conditions(part, dmg)
	if blacked(part) and is_limb(part):
		fracture[part] = true
		bleed[part] = 0
	if blacked(part) and part == Part.STOMACH:
		bleed[part] = 0
	if overflow > 0.0 and part != Part.HEAD and part != Part.CHEST:
		_spread_overflow(part, overflow * OVERFLOW_SHARE)
	_check_death()
	return dmg


## Nadmiar obrażeń ze zniszczonej części rozkłada się po pozostałych (bez głowy).
func _spread_overflow(from_part: int, amount: float) -> void:
	var targets := []
	for p in PARTS:
		if p != from_part and p != Part.HEAD and hp[p] > 0.0:
			targets.append(p)
	if targets.is_empty():
		return
	var each := amount / targets.size()
	for p in targets:
		hp[p] = maxf(0.0, hp[p] - each)
		if blacked(p) and is_limb(p):
			fracture[p] = true
			bleed[p] = 0
	pain = clampf(pain + amount / 150.0, 0.0, 1.0)


func _check_death() -> void:
	if not alive:
		return
	if hp[Part.HEAD] <= 0.0:
		_die("Zniszczenie głowy")
	elif hp[Part.CHEST] <= 0.0:
		_die("Zniszczenie klatki piersiowej")


func _roll_conditions(part: int, dmg: float) -> void:
	if hp[part] <= 0.0:
		return
	if dmg >= 25.0 and randf() < 0.35 + dmg / 200.0:
		bleed[part] = 2
	elif dmg >= 8.0 and bleed[part] < 1 and randf() < 0.3 + dmg / 100.0:
		bleed[part] = 1
	if is_limb(part) and dmg >= 18.0 and not fracture[part] and randf() < 0.2 + dmg / 150.0:
		fracture[part] = true


func tick(delta: float) -> void:
	if not alive:
		return
	for p in PARTS:
		var b: int = bleed[p]
		if b > 0:
			hp[p] = maxf(0.0, hp[p] - (HEAVY_BLEED if b == 2 else LIGHT_BLEED) * delta)
			if blacked(p):
				if p == Part.HEAD or p == Part.CHEST:
					_die("Wykrwawienie")
					return
				bleed[p] = 0
				if is_limb(p):
					fracture[p] = true
	if painkiller_time > 0.0:
		painkiller_time -= delta
		pain = maxf(0.0, pain - 0.15 * delta)
	else:
		pain = maxf(0.0, pain - 0.01 * delta)
	_check_death()


func _die(cause: String) -> void:
	alive = false
	cause_of_death = cause
	died.emit(cause)


func frac(part: int) -> float:
	return hp[part] / maxf(1.0, MAX_HP[part])


func total_frac() -> float:
	var sum := 0.0
	var mx := 0.0
	for p in PARTS:
		sum += hp[p]
		mx += MAX_HP[p]
	return sum / mx


func arms_frac() -> float:
	return (frac(Part.L_ARM) + frac(Part.R_ARM)) / 2.0


func legs_frac() -> float:
	return (frac(Part.L_LEG) + frac(Part.R_LEG)) / 2.0


func painkilled() -> bool:
	return painkiller_time > 0.0


## Mnożnik prędkości: nogi (zniszczona, złamana, ranna). Tabletki łagodzą złamania, nie zniszczenie.
func speed_mult() -> float:
	var m := 1.0
	for leg in [Part.L_LEG, Part.R_LEG]:
		m -= (1.0 - frac(leg)) * 0.12
		if blacked(leg):
			m *= 0.62
		elif fracture[leg]:
			m *= 0.82 if painkilled() else 0.68
	return clampf(m, 0.2, 1.0)


func can_sprint() -> bool:
	for leg in [Part.L_LEG, Part.R_LEG]:
		if blacked(leg) or (fracture[leg] and not painkilled()):
			return false
	return true


## Mnożnik rozrzutu: ręce (ranne, złamane, zniszczone) i ból.
func spread_mult() -> float:
	var m := 1.0 + (1.0 - arms_frac()) * 0.6 + pain * 0.8
	for arm in [Part.L_ARM, Part.R_ARM]:
		if blacked(arm):
			m += 0.5
		elif fracture[arm]:
			m += 0.25 if painkilled() else 0.55
	return m


func reload_mult() -> float:
	var m := 1.0 + (1.0 - arms_frac()) * 0.5
	for arm in [Part.L_ARM, Part.R_ARM]:
		if blacked(arm):
			m += 0.35
		elif fracture[arm]:
			m += 0.1 if painkilled() else 0.25
	return m


func has_bleed(level: int = 0) -> bool:
	for p in PARTS:
		if bleed[p] > level:
			return true
	return false


func bleeding_parts(min_level: int = 1) -> Array:
	var out := []
	for p in PARTS:
		if bleed[p] >= min_level:
			out.append(p)
	return out


func broken_parts() -> Array:
	var out := []
	for p in LIMBS:
		if fracture[p] and not blacked(p):
			out.append(p)
	return out


func blacked_parts() -> Array:
	var out := []
	for p in LIMBS + [Part.STOMACH]:
		if blacked(p):
			out.append(p)
	return out


# --- leczenie (per część) -----------------------------------------------------------

## Bandaż: zatrzymuje lekkie krwawienie na części.
func use_bandage(part: int) -> bool:
	if bleed[part] == 1:
		bleed[part] = 0
		return true
	return false


## Opaska hemostatyczna: zatrzymuje ciężkie (i lekkie) krwawienie na części.
func use_hemostatic(part: int) -> bool:
	if bleed[part] > 0:
		bleed[part] = 0
		return true
	return false


## Szyna: naprawia złamanie kończyny (zniszczona kończyna wymaga operacji).
func use_splint(part: int) -> bool:
	if is_limb(part) and fracture[part] and not blacked(part):
		fracture[part] = false
		return true
	return false


## Apteczka: leczy HP wybranej części (tylko niezniszczonej). Zwraca ilość wyleczonego HP.
func heal(part: int, amount: float) -> float:
	if blacked(part):
		return 0.0
	var give := minf(amount, max_hp[part] - hp[part])
	if give <= 0.0:
		return 0.0
	hp[part] += give
	return give


## Zestaw chirurgiczny: przywraca zniszczoną część, ale z karą do maksymalnego HP.
func use_surgery(part: int) -> bool:
	if not blacked(part) or part == Part.HEAD or part == Part.CHEST:
		return false
	max_hp[part] = maxf(10.0, max_hp[part] * (1.0 - RESTORE_MAX_PENALTY))
	hp[part] = max_hp[part] * RESTORE_HP_FRAC
	fracture[part] = false
	bleed[part] = 0
	return true


func use_painkiller() -> bool:
	painkiller_time = 60.0
	return true


## Czy dana część potrzebuje danego środka (do automatycznego wyboru celu).
func needs(kind: String, part: int) -> bool:
	match kind:
		"bandage": return bleed[part] == 1
		"hemostatic": return bleed[part] > 0
		"splint": return is_limb(part) and fracture[part] and not blacked(part)
		"medkit": return not blacked(part) and hp[part] < max_hp[part] - 0.5
		"surgery": return blacked(part) and part != Part.HEAD and part != Part.CHEST
	return false


## Najlepsza część do automatycznego leczenia danym środkiem; -1 gdy nic nie trzeba.
func auto_target(kind: String) -> int:
	var best := -1
	var best_score := -1.0
	for p in PARTS:
		if not needs(kind, p):
			continue
		var score := 0.0
		match kind:
			"bandage", "hemostatic": score = bleed[p] * 10.0 + (3.0 if p == Part.CHEST or p == Part.HEAD else 0.0)
			"splint": score = 1.0 + (1.0 if is_leg(p) else 0.0)
			"medkit": score = (1.0 - hp[p] / max_hp[p]) * (2.0 if p == Part.CHEST or p == Part.HEAD else 1.0)
			"surgery": score = 1.0 + (1.0 if is_leg(p) else 0.0)
		if score > best_score:
			best_score = score
			best = p
	return best


func status_flags(part: int) -> PackedStringArray:
	var f := PackedStringArray()
	if blacked(part) and part != Part.HEAD and part != Part.CHEST:
		f.append("zniszczona")
	if bleed[part] == 1:
		f.append("krwawienie")
	elif bleed[part] == 2:
		f.append("CIĘŻKIE krwawienie")
	if fracture[part] and not blacked(part):
		f.append("złamanie")
	return f
