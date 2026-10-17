extends Node2D
## Rysuje znikające ślady strzałów.

const LIFETIME := 0.08
var _traces: Array = []  # [from, to, age]


func add_trace(from: Vector2, to: Vector2, color: Color = Color(1.0, 0.9, 0.5)) -> void:
	_traces.append([from, to, 0.0, color])


func _process(delta: float) -> void:
	for t in _traces:
		t[2] += delta
	_traces = _traces.filter(func(t): return t[2] < LIFETIME)
	queue_redraw()


func _draw() -> void:
	for t in _traces:
		var a: float = 1.0 - float(t[2]) / LIFETIME
		var c: Color = t[3]
		draw_line(t[0], t[1], Color(c.r, c.g, c.b, a), 1.0)
