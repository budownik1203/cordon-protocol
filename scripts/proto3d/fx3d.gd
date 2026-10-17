class_name Fx3D
extends RefCounted
## Proste efekty 3D: smuga pocisku, iskry, krew, błysk wystrzału.


static func tracer(parent: Node, from: Vector3, to: Vector3, color: Color = Color(1.0, 0.85, 0.4)) -> void:
	var len := from.distance_to(to)
	if len < 0.1:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.025, 0.025, len)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 3.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	parent.add_child(mi)
	mi.global_position = (from + to) / 2.0
	mi.look_at(to, Vector3.UP)
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.07)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tw.tween_callback(mi.queue_free)


static func burst(parent: Node, pos: Vector3, normal: Vector3, color: Color, amount: int = 8, speed: float = 3.0) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = amount
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.direction = normal
	p.spread = 55.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -9.0, 0)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.05, 0.05)
	p.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 1.5
	p.material_override = m
	parent.add_child(p)
	p.global_position = pos
	var t := Timer.new()
	t.wait_time = 0.8
	t.one_shot = true
	t.autostart = true
	t.timeout.connect(p.queue_free)
	p.add_child(t)


static func flash(parent: Node, pos: Vector3, color: Color = Color(1.0, 0.8, 0.45)) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = 3.5
	l.omni_range = 6.0
	l.shadow_enabled = false
	parent.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.06)
	tw.tween_callback(l.queue_free)
