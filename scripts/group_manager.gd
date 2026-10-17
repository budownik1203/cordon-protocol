class_name GroupManager
extends Node
## Menedżer grupy: łączność radiowa i przydział ról (osłona/flankowanie).

const RADIO_DELAY := 0.6

var members: Array = []  # Enemy
var nav: GridNav
var _pending: Array = []  # [czas, pozycja, źródło]


func add_member(e) -> void:
	members.append(e)
	e.group = self


func report(source, pos: Vector2) -> void:
	_pending.append([RADIO_DELAY, pos, source])


func _process(delta: float) -> void:
	for r in _pending:
		r[0] -= delta
	var due := _pending.filter(func(r): return r[0] <= 0.0)
	_pending = _pending.filter(func(r): return r[0] > 0.0)
	for r in due:
		for m in members:
			if is_instance_valid(m) and m != r[2] and m.body.alive:
				m.receive_radio(r[1])
	_assign_roles()


func alive_members() -> Array:
	return members.filter(func(m): return is_instance_valid(m) and m.body.alive)


## Najbliższy walczący zostaje w osłonie (tłumienie), reszta flankuje.
func _assign_roles() -> void:
	var engaged := alive_members().filter(func(m): return m.is_engaged())
	if engaged.is_empty():
		return
	var anchor = null
	for m in engaged:
		if m.role == "suppress":
			anchor = m
			break
	if anchor == null:
		anchor = engaged[0]
		anchor.role = "suppress"
	for m in engaged:
		if m != anchor and m.role == "":
			m.role = "flank"
