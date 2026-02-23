extends CharacterBody2D

signal fell
signal attack_power_changed(new_power: int)

@export var upward_force := 500.0  # Reducido de 750 para menos rebote vertical
@export var side_force := 400.0  # Reducido de 600 para menos impulso lateral
@export var gravity := 2400.0  # Aumentado para más control y peso
@export var max_speed := 700.0  # Reducido de 900 para más control
@export var reset_y := 800
@export var wall_bounce := 1.2  # Reducido de 1.5 para rebotes más suaves
@export var min_bounce_speed := 100.0  # Reducido de 150 para menos velocidad mínima
@export var initial_attack_power := 5  # Poder de ataque inicial
@export var max_attack_power := 8  # Límite máximo de poder (igual al max_hp de enemigos)

var attack_power: int = initial_attack_power
var base_attack_power: int = initial_attack_power  # Poder base permanente
var temporary_power_boost: int = 0  # Boost temporal actual
var has_fallen := false
var power_boost_timer: Timer
var has_shield := false
var shield_timer: Timer
var poison_active := false  # Estado de un solo uso: al chocar con enemigo más fuerte, aplica veneno sin recibir daño
var poison_grace_timer := 0.0  # Tras aplicar veneno, breve inmunidad para evitar daño por colisiones múltiples (ej. impacto desde arriba)

func _physics_process(delta):
	poison_grace_timer = max(0.0, poison_grace_timer - delta)
	# Aplicamos gravedad
	velocity.y += gravity * delta

	# Movemos la pelota
	move_and_slide()

	# Detectamos colisiones (usamos un set para evitar dañar el mismo enemigo múltiples veces en un frame)
	var hit_enemies = {}
	var poison_used_this_frame := false
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()

		if collider is Enemy:
			var enemy_id = collider.get_instance_id()
			if not hit_enemies.has(enemy_id):
				hit_enemies[enemy_id] = true
				var used_poison = handle_enemy_collision(collider, poison_used_this_frame)
				if used_poison:
					poison_used_this_frame = true

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

	# Aplicamos el impulso de forma más controlada
	# En lugar de establecer directamente, añadimos al impulso existente pero con límite
	velocity.y = -upward_force
	velocity.x -= horizontal * side_force
	
	# Limitamos la velocidad máxima para evitar rebotes excesivos
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed

func pause_ball():
	set_physics_process(false)
	velocity = Vector2.ZERO

func resume_ball():
	set_physics_process(true)
	has_fallen = false
	# Reiniciamos el attack_power al reanudar
	base_attack_power = initial_attack_power
	temporary_power_boost = 0
	attack_power = initial_attack_power
	emit_signal("attack_power_changed", attack_power)
	# Cancelamos cualquier boost temporal activo
	if power_boost_timer:
		power_boost_timer.stop()
		power_boost_timer.queue_free()
		power_boost_timer = null
	
	# Desactivamos el escudo si estaba activo
	_deactivate_shield()
	
	# Desactivamos el veneno si estaba activo
	poison_active = false
	poison_grace_timer = 0.0
	_deactivate_poison_aura()

func handle_enemy_collision(enemy: Enemy, poison_used_this_frame: bool = false) -> bool:
	"""
	Maneja la colisión con un enemigo según la mecánica de enfrentamiento:
	- Si attack_power >= hp → enemigo destruido, bola intacta
	- Si attack_power < hp y poison_active → aplica veneno al enemigo, bola no recibe daño, consume veneno
	- Si attack_power < hp sin veneno → la bola pierde poder y el enemigo se destruye
	- Si poison_used_this_frame → ya usamos veneno este frame, no recibimos daño de otros enemigos
	- Si attack_power llega a 0 → la bola muere
	Retorna true si se aplicó veneno (para proteger de otras colisiones en el mismo frame).
	"""
	if attack_power <= 0:
		return false  # Ya está muerta, no puede hacer nada
	
	var enemy_hp = enemy.hp
	
	if attack_power >= enemy_hp:
		# Enemigo destruido, bola intacta
		enemy.take_damage(enemy_hp)
		return false
	elif poison_active and enemy_hp > attack_power:
		# Veneno activo: aplicamos veneno al enemigo, bola no recibe daño
		if enemy.apply_poison():
			poison_active = false  # Consumimos el veneno (un solo uso por power-up)
			_deactivate_poison_aura()
			poison_grace_timer = 0.5  # Período de gracia: evita daño por colisiones múltiples (impacto desde arriba)
			return true
		return true  # Enemigo ya envenenado, pero la colisión no nos daña
	elif (poison_used_this_frame or poison_grace_timer > 0.0) and enemy_hp > attack_power:
		# Usamos veneno (este frame o recientemente): no recibimos daño de este enemigo
		# Solo rebotamos, el enemigo sigue vivo (evita daño por colisiones múltiples al impactar desde arriba)
		return false
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
		return false

func die_from_combat():
	"""Mata la bola cuando su attack_power llega a 0"""
	if not has_fallen:
		has_fallen = true
		emit_signal("fell")

func _on_powerup_collected(power_amount: int):
	"""Maneja la recolección de un power-up"""
	# Aumentamos el boost temporal
	temporary_power_boost += power_amount
	
	# Calculamos el nuevo poder total (respetando el límite máximo)
	var new_power = base_attack_power + temporary_power_boost
	attack_power = min(new_power, max_attack_power)
	
	emit_signal("attack_power_changed", attack_power)
	
	# Cancelamos el timer anterior si existe
	if power_boost_timer:
		power_boost_timer.stop()
		power_boost_timer.queue_free()
	
	# Creamos un nuevo timer para el boost temporal (5 segundos)
	power_boost_timer = Timer.new()
	power_boost_timer.wait_time = 5.0
	power_boost_timer.one_shot = true
	power_boost_timer.timeout.connect(_on_power_boost_expired)
	add_child(power_boost_timer)
	power_boost_timer.start()

func _on_power_boost_expired():
	"""Se llama cuando expira el boost temporal"""
	temporary_power_boost = 0
	attack_power = base_attack_power
	emit_signal("attack_power_changed", attack_power)
	
	if power_boost_timer:
		power_boost_timer.queue_free()
		power_boost_timer = null

func _on_laser_hit(power_loss: int):
	"""Maneja el impacto con un láser peligroso"""
	if attack_power <= 0:
		return  # Ya está muerta
	
	if has_shield:
		_absorb_hit_with_shield()
		return
	
	# Reducimos el poder de la bola
	attack_power = max(0, attack_power - power_loss)
	emit_signal("attack_power_changed", attack_power)
	
	# Si el poder llega a 0, la bola muere
	if attack_power <= 0:
		die_from_combat()

func _on_misil_hit(power_loss: int):
	"""Maneja el impacto con un misil seguidor"""
	if attack_power <= 0:
		return  # Ya está muerta
	
	if has_shield:
		_absorb_hit_with_shield()
		return
	
	# Reducimos el poder de la bola
	attack_power = max(0, attack_power - power_loss)
	emit_signal("attack_power_changed", attack_power)
	
	# Si el poder llega a 0, la bola muere
	if attack_power <= 0:
		die_from_combat()

func _absorb_hit_with_shield():
	"""El escudo absorbe el impacto y desaparece"""
	has_shield = false
	if shield_timer:
		shield_timer.stop()
		shield_timer.queue_free()
		shield_timer = null
	
	var aura = get_node_or_null("ShieldAura")
	if aura and aura is ShieldAura:
		aura.play_absorb_animation()

func _on_shield_collected(duration: float):
	"""Activa el escudo al recoger el power-up"""
	# Si ya hay escudo, reiniciamos el timer
	if shield_timer:
		shield_timer.stop()
		shield_timer.queue_free()
	
	has_shield = true
	shield_timer = Timer.new()
	shield_timer.wait_time = duration
	shield_timer.one_shot = true
	shield_timer.timeout.connect(_on_shield_expired)
	add_child(shield_timer)
	shield_timer.start()
	
	var aura = get_node_or_null("ShieldAura")
	if aura and aura is ShieldAura:
		aura.activate(duration)

func _on_poison_collected():
	"""Activa el estado poison_active al recoger el power-up (un solo uso)"""
	poison_active = true
	var aura = get_node_or_null("PoisonAura")
	if aura and aura is PoisonAura:
		aura.activate()

func _on_shield_expired():
	"""El escudo expiró por tiempo"""
	has_shield = false
	if shield_timer:
		shield_timer.queue_free()
	shield_timer = null
	
	var aura = get_node_or_null("ShieldAura")
	if aura and aura is ShieldAura:
		aura._deactivate()

func _deactivate_shield():
	"""Desactiva el escudo (ej. al reiniciar partida)"""
	has_shield = false
	if shield_timer:
		shield_timer.stop()
		shield_timer.queue_free()
		shield_timer = null
	
	var aura = get_node_or_null("ShieldAura")
	if aura and aura is ShieldAura:
		aura._deactivate()

func _deactivate_poison_aura():
	"""Desactiva el aura de veneno"""
	var aura = get_node_or_null("PoisonAura")
	if aura and aura is PoisonAura:
		aura.deactivate()

func update_visual(score: int, power: int):
	"""Actualiza la apariencia visual de la bola según score (niveles)"""
	var mesh_instance = get_node_or_null("MeshInstance2D")
	if not mesh_instance:
		return
	
	# Log del poder (para futuro uso cuando implementemos sprites de daño)
	# print("Bola - Poder actual: ", power, " / ", max_attack_power)
	
	# Cambiamos el color según el score (niveles)
	# De blanco (score 0) a negro (score máximo)
	# Usamos un máximo razonable para la progresión (por ejemplo, 50 puntos = negro completo)
	var max_score_for_black = 50.0
	var score_factor = min(float(score) / max_score_for_black, 1.0)  # Normalizado hasta 50 puntos
	
	# Interpolamos entre blanco (1, 1, 1) y negro (0, 0, 0)
	var white_color = Color(1.0, 1.0, 1.0, 1.0)  # Blanco inicial
	var black_color = Color(0.0, 0.0, 0.0, 1.0)  # Negro máximo
	var current_color = white_color.lerp(black_color, score_factor)
	
	mesh_instance.modulate = current_color
	
	# Mantenemos el tamaño original (sin cambios)
	var base_scale = Vector2(50, 50)
	mesh_instance.scale = base_scale
