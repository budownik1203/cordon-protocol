class_name SlotView
extends Control
## Slot sprzętu na ciele (hełm, pancerz, plecak, broń...).

signal slot_input(view: SlotView, event: InputEventMouseButton)
signal hovered(view: SlotView, item: Item)

var slot: String = ""
var equipment: Equipment


func _init() -> void:
	custom_minimum_size = Vector2(56, 32)
	size = custom_minimum_size


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		slot_input.emit(self, event)
	elif event is InputEventMouseMotion:
		hovered.emit(self, equipment.get_slot(slot) if equipment else null)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		hovered.emit(self, null)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.14, 0.15, 0.17))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.37, 0.42), false, 1.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(2, 8), Equipment.SLOT_NAMES.get(slot, slot), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.6, 0.65, 0.7))
	var it: Item = equipment.get_slot(slot) if equipment else null
	if it:
		var r := Rect2(2, 11, size.x - 4, size.y - 13)
		var c := it.color()
		draw_rect(r, c.darkened(0.25))
		draw_rect(r, c.lightened(0.2), false, 1.0)
		draw_string(font, r.position + Vector2(2, 9), it.item_name().substr(0, 13), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 1, 1))
