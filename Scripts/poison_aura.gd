class_name PoisonAura
extends Node2D

## Efecto visual de burbujas de veneno alrededor de la bola cuando poison_active.

@export var bubble_count := 8
@export var bubble_radius := 6.0
@export var orbit_radius := 40.0  # Distancia desde el centro de la bola
@export var float_speed := 2.5
@export var bubble_color := Color(0.45, 0.85, 0.35, 0.9)  # Verde veneno
@export var bubble_color_alt := Color(0.65, 0.4, 0.9, 0.85)  # Violeta alternativo

var _bubbles: Array = []  # { node: Polygon2D, base_angle, phase, orbit_offset }

func _ready():
	visible = false
	_create_bubbles()

func _create_bubbles():
	"""Crea las burbujas alrededor de la bola"""
	for i in range(bubble_count):
		var poly = Polygon2D.new()
		var points = PackedVector2Array()
		for j in range(12):
			var angle = (float(j) / 12.0) * TAU
			points.append(Vector2(cos(angle), sin(angle)) * bubble_radius)
		poly.polygon = points
		poly.color = bubble_color if i % 2 == 0 else bubble_color_alt
		poly.z_index = 4
		add_child(poly)
		
		var base_angle = (float(i) / bubble_count) * TAU
		_bubbles.append({
			"node": poly,
			"base_angle": base_angle,
			"phase": randf() * TAU,
			"orbit_offset": randf_range(-0.3, 0.3)
		})

func _process(delta: float):
	if not visible:
		return
	
	var t = Time.get_ticks_msec() / 1000.0
	for b in _bubbles:
		var poly: Polygon2D = b["node"]
		var angle = b["base_angle"] + t * float_speed * 0.5 + b["phase"] * 0.3
		var wobble = sin(t * float_speed + b["phase"]) * 8.0
		var y_offset = cos(t * 1.2 + b["phase"] * 0.5) * 5.0
		poly.position = Vector2(cos(angle), sin(angle)) * (orbit_radius + wobble)
		poly.position.y += y_offset
		poly.modulate.a = 0.7 + sin(t * 2.0 + b["phase"]) * 0.2

func activate():
	visible = true

func deactivate():
	visible = false
