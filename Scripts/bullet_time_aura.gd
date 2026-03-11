class_name BulletTimeAura
extends Node2D

@export var outer_radius := 46.0
@export var inner_radius := 32.0
@export var marker_count := 8
@export var outer_color := Color(0.72, 0.95, 1.0, 0.85)
@export var inner_color := Color(0.35, 0.75, 1.0, 0.55)
@export var marker_color := Color(1.0, 0.98, 0.82, 0.95)

var _outer_ring: Node2D
var _inner_ring: Node2D
var _hand: Line2D
var _markers: Array = []
var _segments: Array = []

func _ready():
	_create_rings()
	_create_hand()
	_create_markers()
	visible = false

func _process(_delta):
	if not visible:
		return

	var t = Time.get_ticks_msec() / 1000.0
	rotation = t * 0.45
	_inner_ring.rotation = -t * 1.2
	_hand.rotation = -t * 2.4

	for i in range(_markers.size()):
		var marker: Polygon2D = _markers[i]
		var angle = (float(i) / marker_count) * TAU - t * 1.8
		var radius = lerp(inner_radius, outer_radius, 0.55 + 0.15 * sin(t * 3.0 + i))
		marker.position = Vector2(cos(angle), sin(angle)) * radius
		marker.rotation = -angle
		marker.modulate.a = 0.45 + 0.5 * abs(sin(t * 4.0 + i))

func _create_rings():
	_outer_ring = Node2D.new()
	_inner_ring = Node2D.new()
	_create_segmented_ring(_outer_ring, outer_radius, outer_color, 16, 0.72, 3.0)
	_create_segmented_ring(_inner_ring, inner_radius, inner_color, 10, 0.58, 2.0)
	add_child(_outer_ring)
	add_child(_inner_ring)

func _create_hand():
	_hand = Line2D.new()
	_hand.width = 2.5
	_hand.default_color = marker_color
	_hand.z_index = 6
	_hand.points = PackedVector2Array([
		Vector2(0, 8),
		Vector2(0, -inner_radius + 6),
	])
	add_child(_hand)

func _create_markers():
	for i in range(marker_count):
		var marker = Polygon2D.new()
		marker.polygon = PackedVector2Array([
			Vector2(-3, -6),
			Vector2(3, -6),
			Vector2(3, 6),
			Vector2(-3, 6),
		])
		marker.color = marker_color
		marker.z_index = 6
		add_child(marker)
		_markers.append(marker)

func activate(_duration: float):
	visible = true
	scale = Vector2.ONE
	modulate.a = 1.0

func deactivate():
	visible = false
	scale = Vector2.ONE
	rotation = 0.0
	modulate.a = 1.0
	_inner_ring.rotation = 0.0
	_hand.rotation = 0.0

func _create_segmented_ring(parent_node: Node2D, radius: float, color: Color, segments: int, fill_ratio: float, width: float):
	for i in range(segments):
		var segment = Line2D.new()
		segment.width = width
		segment.default_color = color
		segment.z_index = 5
		var start_angle = (float(i) / segments) * TAU
		var end_angle = start_angle + (TAU / segments) * fill_ratio
		segment.points = PackedVector2Array([
			Vector2(cos(start_angle), sin(start_angle)) * radius,
			Vector2(cos(end_angle), sin(end_angle)) * radius,
		])
		parent_node.add_child(segment)
		_segments.append(segment)
