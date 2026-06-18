class_name WallPistons
extends Node2D

signal cycle_finished

enum CycleState {
	IDLE,
	WARNING,
	CLOSING,
	CLOSED,
	OPENING,
	WAITING
}

@export var warning_duration := 0.8
@export var shake_intensity := 4.0
@export var close_duration := 1.0
@export var closed_pause_duration := 0.25
@export var open_duration := 1.35
@export var delay_between_cycles := 1.0
@export var final_gap := 0.0
@export var crush_gap := 66.0
@export var piston_depth := 90.0
@export var piston_height := 152.0
@export var auto_activate := false
@export var repeat_cycles := false
@export var piston_color := Color(0.55, 0.62, 0.72, 1.0)
@export var warning_color := Color(1.0, 0.72, 0.24, 1.0)
@export var active_color := Color(0.86, 0.16, 0.12, 1.0)
@export var piston_collision_layer := 1
@export var piston_collision_mask := 1
@export var player_node_path: NodePath

var left_inner_start := 32.0
var right_inner_start := 1128.0
var trap_y := 320.0

var _state := CycleState.IDLE
var _state_time := 0.0
var _left_body: AnimatableBody2D
var _right_body: AnimatableBody2D
var _left_visual: Polygon2D
var _right_visual: Polygon2D
var _rng := RandomNumberGenerator.new()
var _has_crushed_player := false
var _time_scale := 1.0

func _ready():
	add_to_group("wall_pistons")
	_rng.randomize()
	_build_pistons()
	_apply_open_positions()
	if auto_activate:
		activate()

func configure_bounds(left_inner: float, right_inner: float, y_position: float):
	left_inner_start = left_inner
	right_inner_start = right_inner
	trap_y = y_position
	if is_inside_tree():
		_apply_open_positions()

func activate():
	if _state != CycleState.IDLE:
		return

	_has_crushed_player = false
	_change_state(CycleState.WARNING)

func stop_and_reset():
	_change_state(CycleState.IDLE)
	_has_crushed_player = false
	_apply_open_positions()

func set_time_scale(new_scale: float):
	_time_scale = max(0.01, new_scale)

func _physics_process(delta):
	if _state == CycleState.IDLE:
		return

	_state_time += delta * _time_scale
	match _state:
		CycleState.WARNING:
			_update_warning()
			if _state_time >= warning_duration:
				_change_state(CycleState.CLOSING)
		CycleState.CLOSING:
			_update_motion(close_duration, false)
			_push_trapped_nodes()
			_crush_nodes_if_needed()
			if _state_time >= close_duration:
				_change_state(CycleState.CLOSED)
		CycleState.CLOSED:
			_apply_closed_positions()
			_crush_nodes_if_needed()
			if _state_time >= closed_pause_duration:
				_change_state(CycleState.OPENING)
		CycleState.OPENING:
			_update_motion(open_duration, true)
			if _state_time >= open_duration:
				if repeat_cycles:
					_change_state(CycleState.WAITING)
				else:
					_change_state(CycleState.IDLE)
					emit_signal("cycle_finished")
		CycleState.WAITING:
			_apply_open_positions()
			if _state_time >= delay_between_cycles:
				_change_state(CycleState.WARNING)

func _change_state(new_state: CycleState):
	_state = new_state
	_state_time = 0.0
	_set_visual_color(_color_for_state(new_state))
	if new_state == CycleState.IDLE:
		_apply_open_positions()

func _build_pistons():
	if _left_body:
		return

	_left_body = _create_piston_body("LeftPiston")
	_right_body = _create_piston_body("RightPiston")
	_left_visual = _left_body.get_node("Visual")
	_right_visual = _right_body.get_node("Visual")

func _create_piston_body(body_name: String) -> AnimatableBody2D:
	var body := AnimatableBody2D.new()
	body.name = body_name
	body.collision_layer = piston_collision_layer
	body.collision_mask = piston_collision_mask
	body.sync_to_physics = true
	add_child(body)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(piston_depth, piston_height)

	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	body.add_child(collision)

	var visual := Polygon2D.new()
	visual.name = "Visual"
	visual.color = piston_color
	visual.polygon = PackedVector2Array([
		Vector2(-piston_depth * 0.5, -piston_height * 0.5),
		Vector2(piston_depth * 0.5, -piston_height * 0.5),
		Vector2(piston_depth * 0.5, piston_height * 0.5),
		Vector2(-piston_depth * 0.5, piston_height * 0.5)
	])
	body.add_child(visual)

	return body

func _update_warning():
	var jitter_left := Vector2(_rng.randf_range(-shake_intensity, shake_intensity), _rng.randf_range(-shake_intensity, shake_intensity))
	var jitter_right := Vector2(_rng.randf_range(-shake_intensity, shake_intensity), _rng.randf_range(-shake_intensity, shake_intensity))
	_set_inner_faces(left_inner_start + jitter_left.x, right_inner_start + jitter_right.x, trap_y)
	_left_body.global_position.y += jitter_left.y
	_right_body.global_position.y += jitter_right.y

func _update_motion(duration: float, opening: bool):
	var t := 1.0
	if duration > 0.0:
		t = clamp(_state_time / duration, 0.0, 1.0)
	if opening:
		t = 1.0 - t

	var center_x := _get_center_x()
	var left_closed := center_x - final_gap * 0.5
	var right_closed := center_x + final_gap * 0.5
	var left_inner: float = lerp(left_inner_start, left_closed, t)
	var right_inner: float = lerp(right_inner_start, right_closed, t)
	_set_inner_faces(left_inner, right_inner, trap_y)

func _apply_open_positions():
	_set_inner_faces(left_inner_start, right_inner_start, trap_y)
	_set_visual_color(piston_color)

func _apply_closed_positions():
	var center_x := _get_center_x()
	_set_inner_faces(center_x - final_gap * 0.5, center_x + final_gap * 0.5, trap_y)

func _set_inner_faces(left_inner: float, right_inner: float, y_position: float):
	if not _left_body or not _right_body:
		return

	_left_body.global_position = Vector2(left_inner - piston_depth * 0.5, y_position)
	_right_body.global_position = Vector2(right_inner + piston_depth * 0.5, y_position)

func _push_trapped_nodes():
	var left_inner := _get_left_inner()
	var right_inner := _get_right_inner()
	var center_x := _get_center_x()

	for node in _get_crushable_nodes():
		if not _is_valid_target(node):
			continue
		if not _is_inside_vertical_band(node):
			continue

		var half_width := _estimate_half_width(node)
		var pos := node.global_position
		if pos.x <= center_x and pos.x - half_width < left_inner and pos.x > left_inner_start:
			pos.x = left_inner + half_width
			node.global_position = pos
		elif pos.x > center_x and pos.x + half_width > right_inner and pos.x < right_inner_start:
			pos.x = right_inner - half_width
			node.global_position = pos

func _crush_nodes_if_needed():
	var left_inner := _get_left_inner()
	var right_inner := _get_right_inner()
	var gap := right_inner - left_inner
	if gap > crush_gap:
		return

	_crush_player(left_inner, right_inner)
	for node in _get_crushable_nodes():
		if _is_in_crush_gap(node, left_inner, right_inner):
			_destroy_crushed_node(node)

func _crush_player(left_inner: float, right_inner: float):
	if _has_crushed_player:
		return

	var player := _get_player()
	if not player or not is_instance_valid(player):
		return
	if not _is_in_crush_gap(player, left_inner, right_inner):
		return

	_has_crushed_player = true
	if player.has_method("die_from_hazard"):
		player.die_from_hazard()
	elif player.has_method("die_from_combat"):
		player.die_from_combat()
	elif player.has_signal("fell"):
		player.emit_signal("fell")

func _destroy_crushed_node(node: Node2D):
	if not is_instance_valid(node):
		return

	if node is Enemy and node.has_method("die_from_hazard"):
		node.die_from_hazard()
	elif node is Enemy:
		node.queue_free()
	elif node.has_method("destroy"):
		node.destroy()
	else:
		node.queue_free()

func _get_crushable_nodes() -> Array[Node2D]:
	var nodes: Array[Node2D] = []
	for group_name in [&"enemies", &"powerups", &"misiles", &"player_projectiles"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if node is Node2D:
				nodes.append(node)
	return nodes

func _is_valid_target(node: Node) -> bool:
	if not node or not is_instance_valid(node):
		return false
	if "is_dying" in node and node.is_dying:
		return false
	return true

func _is_inside_vertical_band(node: Node2D) -> bool:
	return abs(node.global_position.y - trap_y) <= piston_height * 0.5

func _is_in_crush_gap(node: Node2D, left_inner: float, right_inner: float) -> bool:
	if not _is_valid_target(node):
		return false
	if not _is_inside_vertical_band(node):
		return false

	var margin: float = max(8.0, _estimate_half_width(node))
	return node.global_position.x >= left_inner - margin and node.global_position.x <= right_inner + margin

func _estimate_half_width(node: Node2D) -> float:
	var collision := node.get_node_or_null("CollisionShape2D")
	if collision and collision is CollisionShape2D and collision.shape:
		var shape = collision.shape
		if shape is CircleShape2D:
			return shape.radius * abs(node.global_scale.x)
		if shape is RectangleShape2D:
			return shape.size.x * 0.5 * abs(collision.global_scale.x)

	return 16.0

func _get_player() -> Node2D:
	if player_node_path != NodePath():
		var assigned := get_node_or_null(player_node_path)
		if assigned and assigned is Node2D:
			return assigned

	var root := get_tree().current_scene
	if root:
		var bola := root.get_node_or_null("Bola")
		if bola and bola is Node2D:
			return bola
	return null

func _get_center_x() -> float:
	return (left_inner_start + right_inner_start) * 0.5

func _get_left_inner() -> float:
	return _left_body.global_position.x + piston_depth * 0.5

func _get_right_inner() -> float:
	return _right_body.global_position.x - piston_depth * 0.5

func _set_visual_color(color: Color):
	if _left_visual:
		_left_visual.color = color
	if _right_visual:
		_right_visual.color = color

func _color_for_state(state: CycleState) -> Color:
	match state:
		CycleState.WARNING:
			return warning_color
		CycleState.CLOSING, CycleState.CLOSED:
			return active_color
		_:
			return piston_color
