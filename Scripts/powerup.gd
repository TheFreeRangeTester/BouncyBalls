class_name PowerUp
extends Area2D

signal powerup_collected(power_amount: int)

@export var power_amount: int = 1  # Cantidad de poder que otorga

func _ready():
	# Conectamos la señal de body_entered para detectar colisiones
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D):
	# Solo reaccionamos si es la bola del jugador
	if body.name == "Bola":
		emit_signal("powerup_collected", power_amount)
		queue_free()  # Desaparece inmediatamente

func set_power_amount(amount: int):
	power_amount = amount
