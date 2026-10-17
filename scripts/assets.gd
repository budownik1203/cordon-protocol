class_name Assets
extends RefCounted
## Ładowanie grafiki i dźwięku z res:// z zapasowym wczytywaniem surowych plików (działa też bez importu edytora).

static var _tex: Dictionary = {}
static var _snd: Dictionary = {}


static func tex(name: String) -> Texture2D:
	if _tex.has(name):
		return _tex[name]
	var path := "res://art/%s.png" % name
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	if t == null and FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null:
			t = ImageTexture.create_from_image(img)
	_tex[name] = t
	return t


static func sound(name: String) -> AudioStream:
	if _snd.has(name):
		return _snd[name]
	var path := "res://audio/%s.wav" % name
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path) as AudioStream
	if s == null and FileAccess.file_exists(path):
		s = _parse_wav(FileAccess.get_file_as_bytes(path))
	_snd[name] = s
	return s


## Prosty parser WAV (16-bit PCM mono/stereo) dla plików nieimportowanych.
static func _parse_wav(bytes: PackedByteArray) -> AudioStreamWAV:
	if bytes.size() < 44:
		return null
	var w := AudioStreamWAV.new()
	var channels := bytes.decode_u16(22)
	w.mix_rate = bytes.decode_u32(24)
	w.stereo = channels == 2
	w.format = AudioStreamWAV.FORMAT_16_BITS
	var pos := 12
	while pos + 8 <= bytes.size():
		var id := bytes.slice(pos, pos + 4).get_string_from_ascii()
		var size := bytes.decode_u32(pos + 4)
		if id == "data":
			w.data = bytes.slice(pos + 8, pos + 8 + size)
			return w
		pos += 8 + size
	return null
