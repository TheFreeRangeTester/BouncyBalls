class_name ElectricPowerUp
extends Area2D

signal electric_collected

@export var lifetime := 15.0

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
	var polygon = get_node_or_null("Polygon2D")
	if not polygon:
		return

	glow_tween = create_tween()
	glow_tween.set_loops()
	glow_tween.tween_property(polygon, "scale", Vector2(1.12, 1.12), 0.35)
	glow_tween.tween_property(polygon, "scale", Vector2.ONE, 0.35)
	glow_tween.parallel().tween_property(polygon, "modulate:a", 0.6, 0.35)
	glow_tween.tween_property(polygon, "modulate:a", 1.0, 0.35)

func _on_body_entered(body: Node2D):
	if body.name == "Bola":
		emit_signal("electric_collected")
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
