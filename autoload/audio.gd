extends Node
## Dźwięk: pula odtwarzaczy (zwykłych i pozycyjnych 2D), pętla tła, losowe warianty wysokości tonu.

const POOL := 20
const MASTER_DB := -3.0

var enabled: bool = true
var _flat: Array = []
var _pos: Array = []
var _fi := 0
var _pi := 0
var _ambient: AudioStreamPlayer
var _amb_name := ""
var _layer: AudioStreamPlayer
var _layer_name := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_flat.append(p)
		var p2 := AudioStreamPlayer2D.new()
		p2.max_distance = 520.0
		p2.attenuation = 1.5
		add_child(p2)
		_pos.append(p2)
	_ambient = AudioStreamPlayer.new()
	add_child(_ambient)
	_layer = AudioStreamPlayer.new()
	add_child(_layer)


## Dźwięk bez pozycji (interfejs, własne kroki, serce).
func play(sound: String, vol_db: float = 0.0, pitch: float = 1.0, vary: float = 0.04) -> void:
	if not enabled:
		return
	var s := Assets.sound(sound)
	if s == null:
		return
	var p: AudioStreamPlayer = _flat[_fi]
	_fi = (_fi + 1) % POOL
	p.stream = s
	p.volume_db = vol_db + MASTER_DB
	p.pitch_scale = pitch * (1.0 + randf_range(-vary, vary))
	p.play()


## Dźwięk w świecie; głośność spada z odległością od kamery.
func play_at(sound: String, pos: Vector2, vol_db: float = 0.0, pitch: float = 1.0, max_dist: float = 520.0, vary: float = 0.04) -> void:
	if not enabled:
		return
	var s := Assets.sound(sound)
	if s == null:
		return
	var p: AudioStreamPlayer2D = _pos[_pi]
	_pi = (_pi + 1) % POOL
	p.stream = s
	p.global_position = pos
	p.max_distance = max_dist
	p.volume_db = vol_db + MASTER_DB
	p.pitch_scale = pitch * (1.0 + randf_range(-vary, vary))
	p.play()


func step(vol_db: float = -6.0) -> void:
	play("step_%d" % (randi() % 3), vol_db, 1.0, 0.08)


func _loop_stream(sound: String) -> AudioStream:
	var s := Assets.sound(sound)
	if s == null:
		return null
	var d := s.duplicate() as AudioStreamWAV
	if d:
		d.loop_mode = AudioStreamWAV.LOOP_FORWARD
		d.loop_begin = 0
		d.loop_end = d.data.size() / (4 if d.stereo else 2)
	return d


func ambient(sound: String, vol_db: float = -14.0) -> void:
	if sound == _amb_name:
		return
	_amb_name = sound
	if not enabled or sound == "":
		_ambient.stop()
		return
	var s := _loop_stream(sound)
	if s == null:
		return
	_ambient.stream = s
	_ambient.volume_db = vol_db + MASTER_DB
	_ambient.play()


## Druga warstwa pętli (np. szepty anomalii) włączana na żądanie.
func layer(sound: String, vol_db: float = -18.0) -> void:
	if sound == _layer_name:
		return
	_layer_name = sound
	if not enabled or sound == "":
		_layer.stop()
		return
	var s := _loop_stream(sound)
	if s == null:
		return
	_layer.stream = s
	_layer.volume_db = vol_db + MASTER_DB
	_layer.play()


func stop_all() -> void:
	_amb_name = ""
	_layer_name = ""
	_ambient.stop()
	_layer.stop()
