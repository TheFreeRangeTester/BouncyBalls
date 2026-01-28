extends Node2D

@export var powerup_scene: PackedScene
@export var spawn_interval := 10.0  # Cada 10 segundos
@export var min_spawn_y := 50.0
@export var min_power_amount := 1
@export var max_power_amount := 3

var max_spawn_y: float
var min_spawn_x: float
var max_spawn_x: float

@onready var timer: Timer = $Timer

func _ready():
	randomize()
	timer.wait_time = spawn_interval
	timer.timeout.connect(_on_timeout)
	calculate_spawn_limits()
	# Iniciamos el timer (se pausará si es necesario desde GameManager)
	timer.start()

func calculate_spawn_limits():
	# Obtenemos los límites basándonos en el viewport y las paredes
	var viewport = get_viewport_rect()
	var screen_bottom = viewport.size.y
	
	# Buscamos la bola para obtener reset_y
	var root = get_tree().root.get_child(0)
	var bola = root.get_node_or_null("Bola")
	
	if bola and "reset_y" in bola:
		screen_bottom = bola.reset_y
	else:
		screen_bottom = viewport.size.y - 100
	
	# Límites Y (altura)
	max_spawn_y = screen_bottom - 100
	
	# Límites X (ancho) - buscamos las paredes
	var walls = root.get_node_or_null("Walls")
	if walls:
		var left_wall = walls.get_node_or_null("LeftWall")
		var right_wall = walls.get_node_or_null("RightWall")
		
		if left_wall and right_wall:
			var left_collision = left_wall.get_node_or_null("CollisionShape2D")
			var right_collision = right_wall.get_node_or_null("CollisionShape2D")
			
			if left_collision and right_collision:
				var left_wall_width = left_collision.shape.size.x
				var right_wall_width = right_collision.shape.size.x
				
				var left_wall_x = left_wall.global_position.x + left_collision.position.x
				var right_wall_x = right_wall.global_position.x + right_collision.position.x
				
				min_spawn_x = left_wall_x + left_wall_width + 50
				max_spawn_x = right_wall_x - right_wall_width - 50
			else:
				# Fallback
				min_spawn_x = 100
				max_spawn_x = viewport.size.x - 100
		else:
			min_spawn_x = 100
			max_spawn_x = viewport.size.x - 100
	else:
		min_spawn_x = 100
		max_spawn_x = viewport.size.x - 100
	
	# Aseguramos que los límites sean válidos
	if max_spawn_y <= min_spawn_y:
		max_spawn_y = min_spawn_y + 100
	if max_spawn_x <= min_spawn_x:
		max_spawn_x = min_spawn_x + 100

func _on_timeout():
	# Solo spawneamos si no hay power-ups visibles en la escena
	var existing_powerups = get_tree().get_nodes_in_group("powerups")
	
	# Filtramos solo los powerups que están dentro de la pantalla visible
	var visible_powerups = []
	var viewport = get_viewport_rect()
	var margin = 100.0
	
	for powerup in existing_powerups:
		if is_instance_valid(powerup):
			var pos = powerup.global_position
			# Verificamos si está dentro de la pantalla visible (con margen)
			if pos.x >= -margin and pos.x <= viewport.size.x + margin and \
			   pos.y >= -margin and pos.y <= viewport.size.y + margin:
				visible_powerups.append(powerup)
	
	if visible_powerups.size() > 0:
		return  # Ya hay uno visible, esperamos al siguiente ciclo
	
	spawn_powerup()

func spawn_powerup():
	if not powerup_scene:
		print("Error: powerup_scene no está asignado en PowerUpSpawner")
		return
		
	var powerup = powerup_scene.instantiate()
	
	# Posición aleatoria dentro del área de juego
	var spawn_x = randf_range(min_spawn_x, max_spawn_x)
	var spawn_y = randf_range(min_spawn_y, max_spawn_y)
	
	powerup.global_position = Vector2(spawn_x, spawn_y)
	
	# Asignamos cantidad de poder aleatoria
	var random_power = randi_range(min_power_amount, max_power_amount)
	if powerup.has_method("set_power_amount"):
		powerup.set_power_amount(random_power)
	else:
		powerup.power_amount = random_power
	
	# Agregamos al grupo
	powerup.add_to_group("powerups")
	
	# Conectamos la señal de recolección a la bola
	var root = get_tree().root.get_child(0)
	var bola = root.get_node_or_null("Bola")
	
	if bola and powerup.has_signal("powerup_collected"):
		powerup.powerup_collected.connect(bola._on_powerup_collected)
	
	get_parent().add_child(powerup)
	print("Power-up spawneado en: ", powerup.global_position)

func pause_spawning():
	timer.stop()

func resume_spawning():
	timer.start()

func reset():
	pause_spawning()
	# Eliminamos todos los power-ups existentes
	for powerup in get_tree().get_nodes_in_group("powerups"):
		powerup.queue_free()
