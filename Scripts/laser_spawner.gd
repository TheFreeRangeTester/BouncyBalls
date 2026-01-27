extends Node2D

@export var laser_scene: PackedScene
@export var spawn_interval := 10.0  # Cada 10 segundos
@export var max_lasers := 2  # Máximo de láseres activos simultáneamente

@onready var timer: Timer = $Timer

func _ready():
	randomize()
	timer.wait_time = spawn_interval
	timer.timeout.connect(_on_timeout)
	timer.start()

func _on_timeout():
	var lasers = get_tree().get_nodes_in_group("lasers")
	if lasers.size() >= max_lasers:
		return
	
	spawn_laser()

func spawn_laser():
	if not laser_scene:
		print("Error: laser_scene no está asignado en LaserSpawner")
		return
	
	# Obtenemos la posición de la bola
	var root = get_tree().root.get_child(0)
	var bola = root.get_node_or_null("Bola")
	
	if not bola:
		print("Error: No se encontró la bola para spawnear el láser")
		return
	
	# Creamos el láser
	var laser = laser_scene.instantiate()
	
	# El láser se posiciona automáticamente en _ready() basándose en la posición de la bola
	# No necesitamos llamar set_laser_position() ya que el láser calcula su propia diagonal
	
	# Agregamos al grupo
	laser.add_to_group("lasers")
	
	# Conectamos la señal de impacto a la bola
	if laser.has_signal("laser_hit"):
		laser.laser_hit.connect(bola._on_laser_hit)
	
	# Conectamos una señal para cuando el láser se destruya (opcional, para limpiar)
	# El láser debería destruirse automáticamente después de un tiempo o cuando sale de pantalla
	
	get_parent().add_child(laser)
	print("Láser spawneado diagonalmente")

func pause_spawning():
	timer.stop()

func resume_spawning():
	timer.start()

func reset():
	pause_spawning()
	# Eliminamos todos los láseres existentes
	for laser in get_tree().get_nodes_in_group("lasers"):
		laser.queue_free()
