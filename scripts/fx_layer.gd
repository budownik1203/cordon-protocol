class_name FxLayer
extends Node2D
## Efekty: ślady strzałów i cząsteczki (krew, iskry, kurz, szlam, błysk wylotowy). Dołącza do grupy "fx".

const LIFETIME := 0.08
const MAX_PARTS := 400
var _traces: Array = []  # [from, to, age, color]
var _parts: Array = []  # [pos, vel, age, life, color, size, drag]


func _ready() -> void:
	add_to_group("fx")


func add_trace(from: Vector2, to: Vector2, color: Color = Color(1.0, 0.9, 0.5)) -> void:
	_traces.append([from, to, 0.0, color])


## Rozbryzg cząsteczek. kind: blood, spark, dust, goo, muzzle. dir: kierunek rozrzutu (zero = we wszystkie strony).
func burst(pos: Vector2, kind: String, dir: Vector2 = Vector2.ZERO, count: int = -1) -> void:
	var n := count
	var spread := PI
	if dir != Vector2.ZERO:
		spread = 0.7
	var col := Color(0.7, 0.08, 0.08)
	var sp_min := 30.0
	var sp_max := 110.0
	var life_min := 0.25
	var life_max := 0.55
	var size := 1.5
	match kind:
		"blood":
			n = 9 if n < 0 else n
		"goo":
			col = Color(0.6, 0.2, 0.7)
			n = 9 if n < 0 else n
		"spark":
			col = Color(1.0, 0.85, 0.35)
			n = 7 if n < 0 else n
			sp_min = 60.0
			sp_max = 170.0
			life_min = 0.12
			life_max = 0.28
			size = 1.0
		"dust":
			col = Color(0.62, 0.6, 0.55)
			n = 5 if n < 0 else n
			sp_min = 15.0
			sp_max = 60.0
			life_min = 0.25
			life_max = 0.5
			size = 1.5
		"muzzle":
			col = Color(1.0, 0.9, 0.55)
			n = 4 if n < 0 else n
			sp_min = 40.0
			sp_max = 120.0
			life_min = 0.04
			life_max = 0.09
			size = 2.0
	for i in n:
		var a := (dir.angle() if dir != Vector2.ZERO else 0.0) + randf_range(-spread, spread)
		var v := Vector2.from_angle(a) * randf_range(sp_min, sp_max)
		var c := col
		if kind == "blood":
			c = col.lerp(Color(0.45, 0.02, 0.02), randf())
		_parts.append([pos, v, 0.0, randf_range(life_min, life_max), c, size * randf_range(0.8, 1.3), 4.0])
	if _parts.size() > MAX_PARTS:
		_parts = _parts.slice(_parts.size() - MAX_PARTS)
	set_process(true)


static func spawn(node: Node, pos: Vector2, kind: String, dir: Vector2 = Vector2.ZERO, count: int = -1) -> void:
	if node == null or not node.is_inside_tree():
		return
	var f := node.get_tree().get_first_node_in_group("fx")
	if f and f.has_method("burst"):
		f.burst(pos, kind, dir, count)


func _process(delta: float) -> void:
	for t in _traces:
		t[2] += delta
	_traces = _traces.filter(func(t): return t[2] < LIFETIME)
	for p in _parts:
		p[2] += delta
		p[0] += p[1] * delta
		p[1] = p[1] * maxf(0.0, 1.0 - p[6] * delta)
	_parts = _parts.filter(func(p): return p[2] < p[3])
	queue_redraw()


func _draw() -> void:
	for t in _traces:
		var a: float = 1.0 - float(t[2]) / LIFETIME
		var c: Color = t[3]
		draw_line(t[0], t[1], Color(c.r, c.g, c.b, a), 1.0)
	for p in _parts:
		var a: float = 1.0 - float(p[2]) / float(p[3])
		var c: Color = p[4]
		var s: float = p[5]
		draw_rect(Rect2(p[0] - Vector2(s, s) * 0.5, Vector2(s, s)), Color(c.r, c.g, c.b, clampf(a * 1.5, 0.0, 1.0)))
