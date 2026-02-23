class_name ShieldPowerUp
extends Area2D

## Power-up de escudo: al recogerlo activa un escudo temporal en la bola
## que absorbe el siguiente misil o láser que la golpee.

signal shield_collected(duration: float)

@export var shield_duration := 8.0  # Segundos que dura el escudo
@export var lifetime := 15.0  # Tiempo antes de auto-destruirse si no se recoge

var lifetime_timer: Timer
var glow_tween: Tween

func _ready():
	body_entered.connect(_on_body_entered)
	
	lifetime_timer = Timer.new()
	lifetime_timer.wait_time = lifetime
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_expired)
	add_child(lifetime_timer)
	lifetime_timer.start()
	
	_start_glow_animation()

func _start_glow_animation():
	"""Pulso suave de brillo para el icono"""
	var polygon = get_node_or_null("Polygon2D")
	if not polygon:
		return
	
	glow_tween = create_tween()
	glow_tween.set_loops()
	glow_tween.tween_property(polygon, "modulate:a", 0.6, 0.6)
	glow_tween.tween_property(polygon, "modulate:a", 1.0, 0.6)

func _on_body_entered(body: Node2D):
	if body.name == "Bola":
		emit_signal("shield_collected", shield_duration)
		queue_free()

func _on_lifetime_expired():
	queue_free()

func _process(_delta):
	var viewport = get_viewport_rect()
	var margin = 200.0
	
	if global_position.y > viewport.size.y + margin or global_position.y < -margin:
		queue_free()
	elif global_position.x > viewport.size.x + margin or global_position.x < -margin:
		queue_free()
