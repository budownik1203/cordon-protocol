extends Node
## Globalna szyna zdarzeń: hałas strzałów i inne sygnały między systemami.

signal noise(position: Vector2, radius: float, source: Node)


func emit_noise(pos: Vector2, radius: float, source: Node = null) -> void:
	noise.emit(pos, radius, source)
