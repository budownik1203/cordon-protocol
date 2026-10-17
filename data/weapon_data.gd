class_name WeaponData
extends Resource
## Opis broni jako dane (Resource). Nowa broń = nowy zasób, bez zmian w kodzie.

@export var display_name: String = "Karabin"
@export var damage: float = 30.0
@export var rounds_per_minute: float = 600.0
@export var magazine_size: int = 30
@export var reload_time: float = 2.2
## Rozrzut bazowy (stopnie), po ustaniu ruchu i odrzutu.
@export var base_spread_deg: float = 1.0
## Dodatkowy rozrzut przy pełnej prędkości ruchu (stopnie).
@export var move_spread_deg: float = 4.0
## Wzrost rozrzutu po każdym strzale (stopnie) i tempo jego wygasania (stopnie/s).
@export var recoil_per_shot_deg: float = 0.9
@export var recoil_recovery_deg: float = 6.0
@export var max_range: float = 600.0
## Penetracja amunicji (1–6) kontra klasa pancerza.
@export_range(1, 6) var penetration: int = 3
## Promień hałasu strzału w pikselach (wrogowie reagują).
@export var noise_radius: float = 300.0


func seconds_per_shot() -> float:
	return 60.0 / rounds_per_minute
