class_name Misil
extends Area2D

signal misil_destroyed
signal misil_hit(power_loss: int)

@export var speed: float = 150.0  # Velocidad de seguimiento
@export var lifetime := 8.0  # Tiempo de vida en segundos (luego explota)
@export var power_loss := 2  # Cantidad de poder que reduce cuando golpea a la bola

var target: Node2D  # La bola que seguirá
var lifetime_timer: Timer
var is_active := true
var time_scale := 1.0

func _ready():
	# Buscamos la bola en la escena
	var root = get_tree().root.get_child(0)
	target = root.get_node_or_null("Bola")
	
	# Conectamos la señal de colisión
	body_entered.connect(_on_body_entered)
	
	# Creamos un timer para auto-destrucción después de 8 segundos (explosión)
	lifetime_timer = Timer.new()
	lifetime_timer.wait_time = lifetime
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_expired)
	add_child(lifetime_timer)
	lifetime_timer.start()
	_sync_time_scale_from_bola()

func _physics_process(delta):
	if not is_active:
		return
	
	if not target or not is_instance_valid(target):
		# Si la bola no existe, buscamos de nuevo o nos destruimos
		var root = get_tree().root.get_child(0)
		target = root.get_node_or_null("Bola")
		if not target:
			queue_free()
			return
	
	# Calculamos la dirección hacia la bola
	var direction = (target.global_position - global_position).normalized()
	
	# Movemos el misil hacia la bola
	global_position += direction * speed * delta * time_scale
	
	# Rotamos el misil para que apunte hacia la dirección de movimiento
	if direction.length() > 0.01:
		rotation = direction.angle() + PI / 2  # Ajustamos para que apunte hacia arriba

func _on_body_entered(body: Node2D):
	# Solo reaccionamos si es la bola del jugador
	if body.name == "Bola":
		# El misil golpea a la bola y causa daño
		emit_signal("misil_hit", power_loss)
		destroy()

func _on_lifetime_expired():
	"""Se llama cuando el misil expira después de 8 segundos y explota"""
	destroy()

func destroy():
	"""Destruye el misil"""
	if not is_active:
		return
	
	is_active = false
	emit_signal("misil_destroyed")
	queue_free()

func pause():
	"""Pausa el misil"""
	is_active = false
	if lifetime_timer:
		lifetime_timer.paused = true
	set_physics_process(false)

func resume():
	"""Reanuda el misil"""
	is_active = true
	if lifetime_timer:
		lifetime_timer.paused = false
	set_physics_process(true)

func set_time_scale(new_scale: float):
	var clamped_scale = max(0.01, new_scale)
	if is_equal_approx(time_scale, clamped_scale):
		return

	_rescale_timer(lifetime_timer, time_scale, clamped_scale)
	time_scale = clamped_scale

func _sync_time_scale_from_bola():
	var root = get_tree().root.get_child(0)
	var bola = root.get_node_or_null("Bola")
	if bola and bola.has_method("get_world_time_scale"):
		set_time_scale(bola.get_world_time_scale())

func _rescale_timer(timer: Timer, old_scale: float, new_scale: float):
	if not timer or timer.is_stopped():
		return

	var was_paused = timer.paused
	var gameplay_remaining = timer.time_left * old_scale
	timer.stop()
	timer.wait_time = gameplay_remaining / new_scale
	timer.start()
	timer.paused = was_paused
