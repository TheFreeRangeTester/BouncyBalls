class_name MissileVolleySet
extends Node2D

signal completed
signal cancelled

@export var shard_scene: PackedScene
@export var projectile_scene: PackedScene
@export var required_shards := 5
@export var time_limit := 15.0
@export var spread_radius := 210.0
@export var min_spacing := 125.0

var shards: Array[MissileVolleyShard] = []
var collected_count := 0
var _is_resolving := false
var _timer: Timer

func start(center: Vector2, min_x: float, max_x: float, min_y: float, max_y: float):
	global_position = Vector2.ZERO
	_spawn_shards(center, min_x, max_x, min_y, max_y)
	_start_timer()

func _spawn_shards(center: Vector2, min_x: float, max_x: float, min_y: float, max_y: float):
	if not shard_scene:
		return

	var points := _build_spawn_points(center, min_x, max_x, min_y, max_y)
	for point in points:
		var shard = shard_scene.instantiate()
		if not (shard is MissileVolleyShard):
			shard.queue_free()
			continue

		var typed_shard: MissileVolleyShard = shard
		typed_shard.global_position = point
		typed_shard.add_to_group("powerups")
		typed_shard.shard_collected.connect(_on_shard_collected)
		typed_shard.tree_exiting.connect(_on_shard_tree_exiting.bind(typed_shard))
		add_child(typed_shard)
		shards.append(typed_shard)

func _build_spawn_points(center: Vector2, min_x: float, max_x: float, min_y: float, max_y: float) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var angle_step := TAU / float(required_shards)
	var base_angle := randf_range(0.0, TAU)

	for i in range(required_shards):
		var angle := base_angle + angle_step * float(i)
		var radius := spread_radius * randf_range(0.72, 1.0)
		var candidate := center + Vector2(cos(angle), sin(angle)) * radius
		candidate.x = clamp(candidate.x, min_x, max_x)
		candidate.y = clamp(candidate.y, min_y, max_y)

		for existing in points:
			if candidate.distance_to(existing) < min_spacing:
				candidate += (candidate - center).normalized() * min_spacing
				candidate.x = clamp(candidate.x, min_x, max_x)
				candidate.y = clamp(candidate.y, min_y, max_y)

		points.append(candidate)

	return points

func _start_timer():
	_timer = Timer.new()
	_timer.wait_time = time_limit
	_timer.one_shot = true
	_timer.timeout.connect(_on_time_expired)
	add_child(_timer)
	_timer.start()

func _on_shard_collected(shard: MissileVolleyShard):
	if _is_resolving:
		return
	if not shards.has(shard):
		return

	collected_count += 1
	if collected_count >= required_shards:
		_complete_set()

func _on_shard_tree_exiting(shard: MissileVolleyShard):
	if _is_resolving:
		return
	if shard.was_collected:
		return

	_cancel_set()

func _on_time_expired():
	if _is_resolving:
		return

	_cancel_set()

func _complete_set():
	_is_resolving = true
	if _timer:
		_timer.stop()
	_fire_enemy_missiles()
	_clear_remaining_shards()
	emit_signal("completed")
	queue_free()

func _cancel_set():
	_is_resolving = true
	if _timer:
		_timer.stop()
	_clear_remaining_shards()
	emit_signal("cancelled")
	queue_free()

func _clear_remaining_shards():
	for shard in shards:
		if is_instance_valid(shard):
			shard.queue_free()
	shards.clear()

func _fire_enemy_missiles():
	if not projectile_scene:
		return

	var root := get_tree().current_scene
	if not root:
		root = get_parent()
	if not root:
		return

	var launch_origin := _get_launch_origin(root)
	for enemy in _get_visible_enemies():
		var projectile = projectile_scene.instantiate()
		if not (projectile is EnemyTargetMissile):
			projectile.queue_free()
			continue

		var missile: EnemyTargetMissile = projectile
		missile.global_position = launch_origin
		missile.set_target(enemy)
		if root.has_node("Bola"):
			var bola = root.get_node("Bola")
			if bola and bola.has_method("get_world_time_scale"):
				missile.set_time_scale(bola.get_world_time_scale())
		root.add_child(missile)

func _get_visible_enemies() -> Array[Enemy]:
	var enemies: Array[Enemy] = []
	var viewport := get_viewport_rect()
	var margin := 40.0
	var bounds := Rect2(Vector2(-margin, -margin), viewport.size + Vector2(margin * 2.0, margin * 2.0))

	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node):
			continue
		if not (node is Enemy):
			continue
		if node.is_dying:
			continue
		if not bounds.has_point(node.global_position):
			continue

		enemies.append(node)

	return enemies

func _get_launch_origin(root: Node) -> Vector2:
	var bola := root.get_node_or_null("Bola")
	if bola and bola is Node2D:
		return bola.global_position

	if shards.size() > 0 and is_instance_valid(shards[0]):
		return shards[0].global_position

	return Vector2.ZERO
