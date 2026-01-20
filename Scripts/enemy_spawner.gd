extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_interval := 2.0
@export var max_enemies := 5
@export var min_spawn_y := 50.0
@export var min_hp := 1  # HP mínimo para enemigos
@export var max_hp := 8  # HP máximo para enemigos

var max_spawn_y: float
var enemy_height: float = 30.0  # Altura aproximada de un enemigo (basada en el scale)

@onready var timer: Timer = $Timer

func _ready():
	randomize()
	timer.wait_time = spawn_interval
	timer.timeout.connect(_on_timeout)
	calculate_spawn_limits()

func calculate_spawn_limits():
	# Obtenemos el límite inferior basándonos en el viewport o en reset_y de la bola
	var viewport = get_viewport_rect()
	var screen_bottom = viewport.size.y
	
	# Buscamos la bola en el nodo principal
	var root = get_tree().root.get_child(0)
	var bola = root.get_node_or_null("Bola")
	
	if bola and "reset_y" in bola:
		screen_bottom = bola.reset_y
	else:
		# Si no encontramos reset_y, usamos el viewport menos un margen
		screen_bottom = viewport.size.y - 100
	
	# Dejamos espacio para al menos 3-4 enemigos abajo (más margen de seguridad)
	# Esto asegura que no spawneen demasiado cerca del fondo
	var bottom_margin = enemy_height * 4 + 100
	max_spawn_y = screen_bottom - bottom_margin
	
	# Aseguramos que max_spawn_y sea mayor que min_spawn_y
	if max_spawn_y <= min_spawn_y:
		max_spawn_y = min_spawn_y + 100

func _on_timeout():
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.size() >= max_enemies:
		return

	spawn_enemy()

func spawn_enemy():
	var enemy = enemy_scene.instantiate()

	# Altura aleatoria
	var spawn_y = randf_range(min_spawn_y, max_spawn_y)

	# Posición X inicial
	var spawn_x = 60  # empieza al lado del límite izquierdo

	enemy.global_position = Vector2(spawn_x, spawn_y)
	
	# Asignamos HP aleatorio al enemigo
	var random_hp = randi_range(min_hp, max_hp)
	if enemy.has_method("set_hp"):
		enemy.set_hp(random_hp)
	else:
		enemy.hp = random_hp

	# Agregamos al grupo
	enemy.add_to_group("enemies")

	# Conectamos la señal de destrucción al GameManager
	# (solo si no está ya conectada para evitar duplicados)
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		# Si no está en un grupo, buscamos directamente
		var root = get_tree().root.get_child(0)
		game_manager = root.get_node_or_null("GameManager")
	
	if game_manager and enemy.has_signal("enemy_destroyed"):
		# Desconectamos primero para evitar duplicados
		if enemy.enemy_destroyed.is_connected(game_manager._on_enemy_destroyed):
			enemy.enemy_destroyed.disconnect(game_manager._on_enemy_destroyed)
		enemy.enemy_destroyed.connect(game_manager._on_enemy_destroyed)

	get_parent().add_child(enemy)

func pause_spawning():
	timer.stop()

func resume_spawning():
	timer.start()

func reset():
	pause_spawning()
	# Eliminamos todos los enemigos que aún existen
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
