class_name PowerUp
extends Area2D

signal powerup_collected(power_amount: int)

@export var power_amount: int = 1  # Cantidad de poder que otorga
@export var lifetime := 15.0  # Tiempo de vida en segundos antes de auto-destruirse

var lifetime_timer: Timer

func _ready():
	# Conectamos la señal de body_entered para detectar colisiones
	body_entered.connect(_on_body_entered)
	
	# Creamos un timer para auto-destrucción después de un tiempo
	lifetime_timer = Timer.new()
	lifetime_timer.wait_time = lifetime
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_expired)
	add_child(lifetime_timer)
	lifetime_timer.start()

func _on_body_entered(body: Node2D):
	# Solo reaccionamos si es la bola del jugador
	if body.name == "Bola":
		emit_signal("powerup_collected", power_amount)
		queue_free()  # Desaparece inmediatamente

func set_power_amount(amount: int):
	power_amount = amount

func _on_lifetime_expired():
	"""Se llama cuando el powerup expira y se auto-destruye"""
	queue_free()

func _process(_delta):
	# Verificamos si el powerup está fuera de la pantalla visible
	var viewport = get_viewport_rect()
	var margin = 200.0  # Margen fuera de la pantalla
	
	if global_position.y > viewport.size.y + margin:
		# Está muy abajo, fuera de la pantalla
		queue_free()
	elif global_position.y < -margin:
		# Está muy arriba, fuera de la pantalla
		queue_free()
	elif global_position.x > viewport.size.x + margin:
		# Está muy a la derecha, fuera de la pantalla
		queue_free()
	elif global_position.x < -margin:
		# Está muy a la izquierda, fuera de la pantalla
		queue_free()
