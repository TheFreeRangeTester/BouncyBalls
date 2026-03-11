class_name ElectricAura
extends Node2D

@export var orbit_radius := 36.0
@export var spark_count := 6
@export var spark_speed := 4.0
@export var link_color := Color(0.45, 0.9, 1.0, 0.9)
@export var radius_color := Color(0.45, 0.9, 1.0, 0.16)

var _sparks: Array = []
var _link_lines: Array[Line2D] = []
var _radius_line: Line2D

func _ready():
	_create_radius_ring()
	_create_sparks()
	visible = false

func _create_radius_ring():
	_radius_line = Line2D.new()
	_radius_line.width = 2.0
	_radius_line.default_color = radius_color
	_radius_line.z_index = 3

	var points = PackedVector2Array()
	for i in range(33):
		var angle = (float(i) / 32.0) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * orbit_radius)
	_radius_line.points = points
	add_child(_radius_line)

func _create_sparks():
	for i in range(spark_count):
		var spark = Polygon2D.new()
		spark.polygon = PackedVector2Array([
			Vector2(-3, -1),
			Vector2(1, -5),
			Vector2(0, -1),
			Vector2(4, -1),
			Vector2(-1, 5),
			Vector2(0, 1),
			Vector2(-4, 1),
		])
		spark.color = link_color
		spark.z_index = 6
		add_child(spark)
		_sparks.append({
			"node": spark,
			"angle": (float(i) / spark_count) * TAU,
			"phase": randf() * TAU,
		})

func _process(_delta):
	if not visible:
		return

	var t = Time.get_ticks_msec() / 1000.0
	for spark_data in _sparks:
		var spark: Polygon2D = spark_data["node"]
		var angle = spark_data["angle"] + t * spark_speed + sin(t * 2.0 + spark_data["phase"]) * 0.25
		var radius = orbit_radius + sin(t * 5.0 + spark_data["phase"]) * 6.0
		spark.position = Vector2(cos(angle), sin(angle)) * radius
		spark.rotation = angle + PI / 2.0
		spark.modulate.a = 0.65 + 0.35 * abs(sin(t * 6.0 + spark_data["phase"]))

func activate(_duration: float, link_radius: float):
	orbit_radius = max(36.0, link_radius * 0.28)
	_update_radius_ring()
	visible = true

func update_links(targets: Array[Enemy]):
	if not visible:
		return

	var index := 0
	for enemy in targets:
		var line = _ensure_link_line(index)
		line.visible = true
		line.position = Vector2.ZERO
		var local_enemy_position = to_local(enemy.global_position)
		line.points = PackedVector2Array([
			Vector2.ZERO,
			local_enemy_position * 0.45 + Vector2(randf_range(-8.0, 8.0), randf_range(-10.0, 10.0)),
			local_enemy_position,
		])
		index += 1

	for i in range(index, _link_lines.size()):
		_link_lines[i].visible = false

func deactivate():
	visible = false
	for line in _link_lines:
		line.visible = false

func _ensure_link_line(index: int) -> Line2D:
	if index < _link_lines.size():
		return _link_lines[index]

	var line = Line2D.new()
	line.width = 3.0
	line.default_color = link_color
	line.z_index = 5
	add_child(line)
	_link_lines.append(line)
	return line

func _update_radius_ring():
	if not _radius_line:
		return

	var points = PackedVector2Array()
	for i in range(33):
		var angle = (float(i) / 32.0) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * orbit_radius)
	_radius_line.points = points
