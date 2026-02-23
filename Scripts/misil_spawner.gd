extends Node2D

@export var misil_scene: PackedScene
@export var spawn_interval := 5.0  # Intervalo entre spawns
@export var max_misiles := 3  # Máximo de misiles activos simultáneamente

@onready var timer: Timer = $Timer

func _ready():
	randomize()
	timer.wait_time = spawn_interval
	timer.timeout.connect(_on_timeout)
	# NO iniciamos el timer automáticamente - el ProgressionManager lo controlará
	# timer.start()  # Comentado - se iniciará cuando el ProgressionManager lo active

func _on_timeout():
	var misiles = get_tree().get_nodes_in_group("misiles")
	if misiles.size() >= max_misiles:
		return
	
	spawn_misil()

func spawn_misil():
	if not misil_scene:
		print("Error: misil_scene no está asignado en MisilSpawner")
		return
	
	# Obtenemos el tamaño del viewport
	var viewport = get_viewport_rect()
	var screen_width = viewport.size.x
	var screen_height = viewport.size.y
	
	# Buscamos la bola para obtener reset_y si está disponible
	var root = get_tree().root.get_child(0)
	var bola = root.get_node_or_null("Bola")
	
	# Calculamos la posición Y desde la base de la pantalla
	var spawn_y: float
	if bola and "reset_y" in bola:
		spawn_y = bola.reset_y - 20  # Un poco arriba del fondo
	else:
		spawn_y = screen_height - 50  # Margen desde el fondo
	
	# Posición X aleatoria a lo largo del eje horizontal
	# Dejamos margen para que no spawneen dentro de las paredes
	var margin = 60.0
	var spawn_x = randf_range(margin, screen_width - margin)
	
	# Creamos el misil
	var misil = misil_scene.instantiate()
	misil.global_position = Vector2(spawn_x, spawn_y)
	
	# Agregamos al grupo
	misil.add_to_group("misiles")
	
	# Conectamos la señal de impacto a la bola
	if misil.has_signal("misil_hit") and bola:
		misil.misil_hit.connect(bola._on_misil_hit)
	
	get_parent().add_child(misil)
	print("Misil spawneado en posición: ", misil.global_position)

func pause_spawning():
	if timer:
		timer.stop()

func resume_spawning():
	if timer:
		timer.start()

func reset():
	pause_spawning()
	# Eliminamos todos los misiles existentes
	for misil in get_tree().get_nodes_in_group("misiles"):
		misil.queue_free()

func set_max_misiles(new_max: int):
	"""Ajusta la cantidad máxima de misiles activos según la progresión"""
	max_misiles = max(0, new_max)
