class_name EnemyTargetMissile
extends Area2D

@export var speed := 420.0
@export var hit_radius := 18.0
@export var lifetime := 4.0

var target: Enemy
var _time_left := 4.0
var _time_scale := 1.0

func _ready():
	_time_left = lifetime
	add_to_group("player_projectiles")

func set_target(new_target: Enemy):
	target = new_target

func _physics_process(delta):
	var scaled_delta: float = delta * _time_scale
	_time_left -= scaled_delta
	if _time_left <= 0.0:
		queue_free()
		return

	if not target or not is_instance_valid(target) or target.is_dying:
		queue_free()
		return

	var direction := target.global_position - global_position
	if direction.length() <= hit_radius:
		_hit_target()
		return

	var velocity: Vector2 = direction.normalized() * speed * scaled_delta
	global_position += velocity
	rotation = direction.angle()

func set_time_scale(new_scale: float):
	_time_scale = max(0.01, new_scale)

func _hit_target():
	if target and is_instance_valid(target) and not target.is_dying:
		target.take_damage(target.hp)
	queue_free()
