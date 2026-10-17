extends Node
## Rejestruje akcje wejścia w kodzie, żeby nie zależeć od edytora.


func _ready() -> void:
	_key("move_up", KEY_W)
	_key("move_down", KEY_S)
	_key("move_left", KEY_A)
	_key("move_right", KEY_D)
	_key("reload", KEY_R)
	_key("crouch", KEY_C)
	_key("sprint", KEY_SHIFT)
	_key("interact", KEY_E)
	_key("inventory", KEY_TAB)
	_key("swap_weapon", KEY_Q)
	_key("use_bandage", KEY_1)
	_key("use_hemostatic", KEY_2)
	_key("use_splint", KEY_3)
	_key("use_painkiller", KEY_4)
	_key("restart", KEY_ENTER)
	_mouse("fire", MOUSE_BUTTON_LEFT)


func _key(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)


func _mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
