class_name LootBox
extends Node2D
## Kontener w świecie (szafka, skrzynia, biurko, sejf) lub ciało. Przeszukiwanie odsłania zawartość stopniowo.

var kind: String = "szafka"
var bag: Bag
var is_corpse: bool = false
var searched: bool = false  # czy ktoś już zaczął przeszukiwać
var reveal_timer: float = 0.0
const REVEAL_STEP := 0.6

const KIND_COLORS := {
	"szafka": Color(0.45, 0.5, 0.55), "skrzynia": Color(0.5, 0.4, 0.22),
	"biurko": Color(0.45, 0.35, 0.28), "sejf": Color(0.6, 0.6, 0.3),
}
const KIND_NAMES := {"szafka": "Szafka", "skrzynia": "Skrzynia", "biurko": "Biurko", "sejf": "Sejf"}


func setup(p_kind: String, items: Array, corpse: bool = false) -> void:
	kind = p_kind
	is_corpse = corpse
	var cols := 5
	var rows := 4
	match kind:
		"skrzynia": cols = 6; rows = 4
		"sejf": cols = 4; rows = 3
		"szafka": cols = 5; rows = 3
		"biurko": cols = 4; rows = 3
	if corpse:
		cols = 6
		rows = 5
	bag = Bag.grid(cols, rows)
	for it in items:
		it.revealed = false
		if not bag.add_auto(it):
			continue


func display_name() -> String:
	if is_corpse:
		return "Ciało (%s)" % kind
	return KIND_NAMES.get(kind, kind)


func has_hidden() -> bool:
	for it in bag.items:
		if not it.revealed:
			return true
	return false


## Odsłania kolejny przedmiot; zwraca true, gdy coś odsłonięto.
func reveal_step(delta: float) -> bool:
	if not has_hidden():
		return false
	reveal_timer += delta
	if reveal_timer >= REVEAL_STEP:
		reveal_timer = 0.0
		for it in bag.items:
			if not it.revealed:
				it.revealed = true
				queue_redraw()
				return true
	return false


func _draw() -> void:
	if is_corpse:
		draw_circle(Vector2.ZERO, 7.0, Color(0.28, 0.2, 0.2))
		draw_line(Vector2(-5, -3), Vector2(5, 3), Color(0.15, 0.1, 0.1), 2.0)
		return
	var c: Color = KIND_COLORS.get(kind, Color(0.5, 0.5, 0.5))
	draw_rect(Rect2(-9, -9, 18, 18), c)
	draw_rect(Rect2(-9, -9, 18, 18), c.darkened(0.5), false, 1.0)
	if not bag.items.is_empty():
		draw_rect(Rect2(-2, -2, 4, 4), Color(0.95, 0.85, 0.3))
