class_name VFXManager
extends Node2D

## Sistema centralizado para disparar VFX reutilizables en gameplay.
## Todos los efectos se crean de forma programática con CPUParticles2D.
var particle_texture: Texture2D

func emit_effect(effect_id: StringName, world_position: Vector2):
	match effect_id:
		&"enemy_kill":
			_emit_enemy_kill(world_position)
		&"poison_hit":
			_emit_poison_hit(world_position)
		&"shield_block":
			_emit_shield_block(world_position)
		&"lava_splash":
			_emit_lava_splash(world_position)
		&"ball_hurt":
			_emit_ball_hurt(world_position)

func _ready():
	particle_texture = _build_particle_texture()

func _emit_enemy_kill(pos: Vector2):
	var p = _make_particles(pos, 20, 0.45)
	p.direction = Vector2.UP
	p.spread = 85.0
	p.gravity = Vector2(0, 900)
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 260.0
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.5
	p.color_ramp = _make_gradient([
		Color(0.95, 0.12, 0.12, 0.95),
		Color(0.65, 0.02, 0.08, 0.55),
		Color(0.35, 0.0, 0.02, 0.0)
	])

func _emit_poison_hit(pos: Vector2):
	var p = _make_particles(pos, 24, 0.6)
	p.direction = Vector2.UP
	p.spread = 100.0
	p.gravity = Vector2(0, 620)
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 190.0
	p.scale_amount_min = 2.4
	p.scale_amount_max = 5.2
	p.color_ramp = _make_gradient([
		Color(0.50, 1.0, 0.30, 0.9),
		Color(0.20, 0.72, 0.15, 0.5),
		Color(0.10, 0.25, 0.08, 0.0)
	])

func _emit_shield_block(pos: Vector2):
	var p = _make_particles(pos, 28, 0.35)
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 150.0
	p.initial_velocity_max = 300.0
	p.angular_velocity_min = -500.0
	p.angular_velocity_max = 500.0
	p.scale_amount_min = 2.2
	p.scale_amount_max = 4.8
	p.color_ramp = _make_gradient([
		Color(0.55, 0.95, 1.0, 0.95),
		Color(0.35, 0.70, 1.0, 0.55),
		Color(0.10, 0.35, 0.70, 0.0)
	])

func _emit_lava_splash(pos: Vector2):
	var p = _make_particles(pos, 18, 0.5)
	p.direction = Vector2.UP
	p.spread = 60.0
	p.gravity = Vector2(0, 1100)
	p.initial_velocity_min = 140.0
	p.initial_velocity_max = 260.0
	p.scale_amount_min = 2.8
	p.scale_amount_max = 6.0
	p.color_ramp = _make_gradient([
		Color(1.0, 0.85, 0.20, 0.95),
		Color(1.0, 0.45, 0.08, 0.65),
		Color(0.40, 0.10, 0.03, 0.0)
	])

func _emit_ball_hurt(pos: Vector2):
	var p = _make_particles(pos, 16, 0.35)
	p.direction = Vector2.UP
	p.spread = 170.0
	p.gravity = Vector2(0, 850)
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 220.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.2
	p.color_ramp = _make_gradient([
		Color(1.0, 0.92, 0.40, 0.95),
		Color(1.0, 0.42, 0.12, 0.75),
		Color(0.55, 0.05, 0.02, 0.0)
	])

func _make_particles(pos: Vector2, amount: int, lifetime: float) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.global_position = pos
	particles.one_shot = true
	particles.amount = amount
	particles.lifetime = lifetime
	particles.local_coords = false
	particles.explosiveness = 0.9
	particles.texture = particle_texture
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 6.0
	particles.z_index = 25
	add_child(particles)

	particles.emitting = true
	_cleanup_after(particles, lifetime + 0.45)
	return particles

func _cleanup_after(node: Node, delay: float):
	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(_on_cleanup_timeout.bind(node))

func _on_cleanup_timeout(node: Node):
	if is_instance_valid(node):
		node.queue_free()

func _make_gradient(colors: Array[Color]) -> Gradient:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray(colors)
	return gradient

func _build_particle_texture() -> Texture2D:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(7.5, 7.5)
	var radius := 7.5
	for y in range(16):
			for x in range(16):
				var d = Vector2(float(x), float(y)).distance_to(center)
				if d <= radius:
					var alpha: float = 1.0 - (d / radius)
					image.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(image)
