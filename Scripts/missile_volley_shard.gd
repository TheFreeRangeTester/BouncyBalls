class_name MissileVolleyShard
extends Area2D

signal shard_collected(shard: MissileVolleyShard)

var was_collected := false
var _pulse_tween: Tween

func _ready():
	body_entered.connect(_on_body_entered)
	_start_pulse()

func _on_body_entered(body: Node2D):
	if was_collected:
		return
	if body.name != "Bola":
		return

	was_collected = true
	emit_signal("shard_collected", self)
	queue_free()

func _start_pulse():
	var visual := get_node_or_null("Polygon2D")
	if not visual:
		return

	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(visual, "scale", Vector2(1.18, 1.18), 0.35)
	_pulse_tween.tween_property(visual, "scale", Vector2.ONE, 0.35)
