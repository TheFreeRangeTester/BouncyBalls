class_name WallPistonSpawner
extends Node2D

@export var piston_scene: PackedScene
@export var bola: CharacterBody2D
@export var walls: Node2D
@export var bottom_hazard: Node2D
@export var spawn_interval := 15.0
@export var debug_spawn_interval := 5.0
@export var score_threshold := 20
@export var piston_height := 152.0
@export var top_margin := 85.0
@export var bottom_margin := 95.0
@export var wall_clearance := 0.0
@export var warning_duration := 0.8
@export var shake_intensity := 4.0
@export var close_duration := 1.0
@export var closed_pause_duration := 0.25
@export var open_duration := 1.35
@export var final_gap := 0.0
@export var crush_gap := 66.0

var is_enabled := false
var active_piston: WallPistons
var timer: Timer
var _rng := RandomNumberGenerator.new()
var _normal_spawn_interval := 15.0

func _ready():
	_rng.randomize()
	_normal_spawn_interval = spawn_interval
	_resolve_references()
	timer = Timer.new()
	timer.name = "Timer"
	timer.wait_time = spawn_interval
	timer.one_shot = false
	timer.timeout.connect(_on_timeout)
	add_child(timer)

func set_enabled(enabled: bool):
	is_enabled = enabled
	if not timer:
		return

	if is_enabled:
		timer.wait_time = spawn_interval
		if timer.is_stopped():
			timer.start()
	else:
		timer.stop()

func enable_debug_spawning():
	spawn_interval = debug_spawn_interval
	set_enabled(true)

func disable_debug_spawning():
	spawn_interval = _normal_spawn_interval
	set_enabled(false)

func pause_spawning():
	if timer:
		timer.stop()

func resume_spawning():
	if is_enabled and timer:
		timer.start()

func reset():
	pause_spawning()
	is_enabled = false
	spawn_interval = _normal_spawn_interval
	if active_piston and is_instance_valid(active_piston):
		active_piston.queue_free()
	active_piston = null

func _on_timeout():
	if not is_enabled:
		return
	if active_piston and is_instance_valid(active_piston):
		return

	spawn_pistons()

func spawn_pistons():
	if not piston_scene:
		print("WallPistonSpawner: piston_scene no esta asignado")
		return

	_resolve_references()

	var bounds := _get_wall_inner_bounds()
	var spawn_y := _get_safe_spawn_y()
	if spawn_y < 0.0:
		return

	var pistons = piston_scene.instantiate()
	if not (pistons is WallPistons):
		print("WallPistonSpawner: la escena asignada no es WallPistons")
		pistons.queue_free()
		return

	active_piston = pistons
	active_piston.piston_height = piston_height
	active_piston.warning_duration = warning_duration
	active_piston.shake_intensity = shake_intensity
	active_piston.close_duration = close_duration
	active_piston.closed_pause_duration = closed_pause_duration
	active_piston.open_duration = open_duration
	active_piston.final_gap = final_gap
	active_piston.crush_gap = crush_gap
	active_piston.auto_activate = false
	active_piston.repeat_cycles = false

	get_parent().add_child(active_piston)
	active_piston.configure_bounds(bounds.x + wall_clearance, bounds.y - wall_clearance, spawn_y)
	if bola:
		active_piston.player_node_path = active_piston.get_path_to(bola)
	active_piston.cycle_finished.connect(_on_piston_cycle_finished.bind(active_piston))
	active_piston.activate()

func _on_piston_cycle_finished(piston: WallPistons):
	if active_piston == piston:
		active_piston = null
	if is_instance_valid(piston):
		piston.queue_free()

func _resolve_references():
	if not is_inside_tree():
		return

	var root := get_tree().current_scene
	if not root:
		root = get_parent()
	if not root:
		return

	if not bola:
		bola = root.get_node_or_null("Bola")
	if not walls:
		walls = root.get_node_or_null("Walls")
	if not bottom_hazard:
		bottom_hazard = root.get_node_or_null("BottomSpikes")

func _get_wall_inner_bounds() -> Vector2:
	if walls:
		var left_wall := walls.get_node_or_null("LeftWall")
		var right_wall := walls.get_node_or_null("RightWall")
		var left_inner := _get_wall_inner_edge(left_wall, true)
		var right_inner := _get_wall_inner_edge(right_wall, false)
		if left_inner < right_inner:
			return Vector2(left_inner, right_inner)

	var viewport := get_viewport_rect()
	return Vector2(32.0, viewport.size.x - 32.0)

func _get_wall_inner_edge(wall: Node2D, is_left_wall: bool) -> float:
	if not wall:
		return INF if is_left_wall else -INF

	var collision := wall.get_node_or_null("CollisionShape2D")
	if not collision or not (collision is CollisionShape2D) or not collision.shape:
		return INF if is_left_wall else -INF

	var shape = collision.shape
	if shape is RectangleShape2D:
		var center_x: float = collision.global_position.x
		var half_width: float = shape.size.x * 0.5 * abs(collision.global_scale.x)
		return center_x + half_width if is_left_wall else center_x - half_width

	return INF if is_left_wall else -INF

func _get_safe_spawn_y() -> float:
	var top_limit := top_margin + piston_height * 0.5
	var bottom_limit := _get_bottom_limit() - bottom_margin - piston_height * 0.5
	if bottom_limit <= top_limit:
		print("WallPistonSpawner: no hay espacio vertical seguro para pistones")
		return -1.0

	return _rng.randf_range(top_limit, bottom_limit)

func _get_bottom_limit() -> float:
	if bottom_hazard:
		return bottom_hazard.global_position.y
	if bola and "reset_y" in bola:
		return bola.reset_y
	return get_viewport_rect().size.y - 40.0
