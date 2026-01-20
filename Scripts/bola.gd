extends CharacterBody2D

signal fell
signal attack_power_changed(new_power: int)

@export var upward_force := 750.0
@export var side_force := 600.0
@export var gravity := 1200.0
@export var max_speed := 900.0
@export var reset_y := 800
@export var wall_bounce := 1.5
@export var min_bounce_speed := 150.0
@export var initial_attack_power := 5  # Poder de ataque inicial

var attack_power: int = initial_attack_power
var has_fallen := false

func _physics_process(delta):
	# Aplicamos gravedad
	velocity.y += gravity * delta

	# Movemos la pelota
	move_and_slide()

	# Detectamos colisiones (usamos un set para evitar dañar el mismo enemigo múltiples veces en un frame)
	var hit_enemies = {}
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()

		if collider is Enemy:
			var enemy_id = collider.get_instance_id()
			if not hit_enemies.has(enemy_id):
				hit_enemies[enemy_id] = true
				handle_enemy_collision(collider)

	# Rebote manual contra paredes
	handle_wall_bounce_manual()

	# Señal si cae fuera de la pantalla
	if global_position.y > reset_y and not has_fallen:
		has_fallen = true
		emit_signal("fell")

func handle_wall_bounce_manual():
	if is_on_wall():
		# Aseguramos una velocidad mínima lateral
		if abs(velocity.x) < min_bounce_speed:
			velocity.x = min_bounce_speed * (1 if velocity.x >= 0 else -1)

		velocity.x = -velocity.x * wall_bounce

func _input(event):
	if (event is InputEventScreenTouch and event.pressed) \
	or (event is InputEventMouseButton and event.pressed):
		juggle_impulse()

func juggle_impulse():
	var tap_pos = get_global_mouse_position()
	var dx = tap_pos.x - global_position.x
	var horizontal = clamp(dx / 300.0, -1.0, 1.0)

	velocity.y = -upward_force
	velocity.x -= horizontal * side_force

	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed

func pause_ball():
	set_physics_process(false)
	velocity = Vector2.ZERO

func resume_ball():
	set_physics_process(true)
	has_fallen = false
	# Reiniciamos el attack_power al reanudar
	attack_power = initial_attack_power
	emit_signal("attack_power_changed", attack_power)

func handle_enemy_collision(enemy: Enemy):
	"""
	Maneja la colisión con un enemigo según la mecánica de enfrentamiento:
	- Si attack_power >= hp → enemigo destruido, bola intacta
	- Si attack_power < hp → la bola pierde (hp - attack_power) de attack_power
	- Si attack_power llega a 0 → la bola muere
	"""
	if attack_power <= 0:
		return  # Ya está muerta, no puede hacer nada
	
	var enemy_hp = enemy.hp
	
	if attack_power >= enemy_hp:
		# Enemigo destruido, bola intacta
		enemy.take_damage(enemy_hp)
	else:
		# La bola pierde la diferencia (hp - attack_power)
		var power_lost = enemy_hp - attack_power
		attack_power = max(0, attack_power - power_lost)
		emit_signal("attack_power_changed", attack_power)
		
		# Destruimos el enemigo también (aunque la bola pierde poder)
		enemy.take_damage(enemy_hp)
		
		# Si attack_power llegó a 0, la bola muere
		if attack_power <= 0:
			die_from_combat()

func die_from_combat():
	"""Mata la bola cuando su attack_power llega a 0"""
	if not has_fallen:
		has_fallen = true
		emit_signal("fell")
